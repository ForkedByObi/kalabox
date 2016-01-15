/**
 * Contains network handling suff
 * @module machine.net
 */

'use strict';

module.exports = function(kbox) {

  // NPM modules
  var _ = require('lodash');

  // Kalabox modules
  var Promise = kbox.Promise;
  var shell = kbox.util.shell;

  // Provider config
  var providerConfig = kbox.core.deps.get('providerConfig');

  // Set some machine things
  var MACHINE_CONFIG = providerConfig.machine.kalabox;

  /*
   * Helper to get the vbox exec
   */
  var getVboxExec = function() {

    var winVBox = '"C:\\Program Files\\Oracle\\VirtualBox\\VBoxManage.exe"';

    // Return path based on platform
    switch (process.platform) {
      case 'win32': return winVBox;
      case 'darwin': return 'VBoxManage';
      case 'linux': return 'VBoxManage';
    }

  };

  /*
   * Return netsh parsed vbox adapter name
   */
  var adapterToWin = function(adapter) {
    return adapter.replace('Ethernet Adapter', 'Network');
  };

  /*
   * Get the correct windows network adapter
   */
  var getKalaboxAdapter = function() {

    // Command to run
    var cmd = [
      getVboxExec(),
      'showvminfo "Kalabox2" | findstr "Host-only"'
    ];

    // Get network information from virtual box.
    return shell(cmd.join(' '))

    // Parse the output
    .then(function(output) {

      // Debug log output
      kbox.core.log.debug('ADAPTER INFO => ' + JSON.stringify(output));

      // Parse output to get network adapter information.
      var start = output.indexOf('\'');
      var last = output.lastIndexOf('\'');
      var adapter = output.slice(start + 1, last);

      // debug
      kbox.core.log.debug('WINDOWS ADAPTER => ' + JSON.stringify(adapter));

      // Return
      return adapter;
    });

  };

  /*
   * Get the correct windows network adapter
   */
  var getWindowsAdapters = function() {

    // Command to run
    var cmd = [
      getVboxExec(),
      'list hostonlyifs'
    ];

    // Get network information from virtual box.
    return shell(cmd.join(' '))

    // Parse the output
    .then(function(output) {

      var rawAdapters = output.split('\r\n\r\n');
      rawAdapters.pop();

      // Map raw adapters to objectified adapters
      var adapters = _.map(rawAdapters, function(rawAdapter) {

        // Split the raw adapter into lines
        var lines = rawAdapter.split('\r\n');

        // Split lines into key|value pairs
        var adapter = {};
        _.forEach(lines, function(line) {
          var splitter = line.split(':');
          adapter[_.trim(splitter[0]).toLowerCase()] = _.trim(splitter[1]);
        });

        // Return the object
        return adapter;
      });

      // Return
      return adapters;
    });

  };

  /*
   * Check the status of our host only adapter
   */
  var isHostOnlySet = function() {

    // Grab the default HOA
    var ip = MACHINE_CONFIG.host;

    // Grab the host only adapter so we can be SUPER PRECISE!
    return getKalaboxAdapter()

    // Get network information from virtual box.
    .then(function(adapter) {

      var adp = adapterToWin(adapter);

      // Command to run
      var cmd = 'netsh interface ipv4 show addresses';

      // Execute promisified shell
      return shell(cmd)

      // Need to catch findstr null reporting as error
      .catch(function(/*err*/) {
        // @todo: something more precise here
      })

      .then(function(output) {
        // Truncate the string for just data on what we need
        // This elminates the possibility that another adapter has our
        // setup. Although, to be fair, if another adapter does then
        // we are probably SOL anyway.

        // Trim the left
        var leftTrim = 'Configuration for interface "' + adp + '"';
        var truncLeft = output.indexOf(leftTrim);
        var left = output.slice(truncLeft);

        // Trim the right
        var rightTrim = 'Subnet Prefix';
        var truncRight = left.indexOf(rightTrim);

        // Return precise
        return left.slice(0, truncRight);
      });

    })

    // Parse the output
    .then(function(output) {

      // Parse output
      var isSet = _.includes(output, ip);

      // Debug log output
      kbox.core.log.debug('ADAPTER SET CORRECTLY => ' + JSON.stringify(isSet));

      // Return
      return isSet;
    });

  };

  /*
   * Force set the host only adapter if it is not set correctly
   */
  var setHostOnly = function() {

    // Get network information from virtual box.
    return getKalaboxAdapter()

    // Parse the output
    .then(function(adapter) {

      // @todo: Dont hardcode this
      var ip = MACHINE_CONFIG.host;
      var winAdapter = adapterToWin(adapter);
      // Command to run
      var cmd = 'netsh interface ipv4 set address name="' + winAdapter + '" ' +
        'static ' + ip + ' store=persistent';

      // Debug log output
      kbox.core.log.debug('SETTING ADAPTER => ' + JSON.stringify(cmd));

      // Run an elevated command for this
      return kbox.util.shell.execElevated(cmd);

    })

    // Set a reasonable timeout to make sure this takes effect
    .delay(10 * 1000);

  };

  /*
   * Set up dns resolution
   */
  var setHostDnsResolver = function() {

    // Retry the linxu sharing a few times
    return Promise.retry(function(/*counter*/) {

      // VBOXMANAGE dns resolver
      var cmd = [
        getVboxExec(),
        'modifyvm "Kalabox2"',
        '--natdnshostresolver1 on'];

      // Run the command
      return shell(cmd.join(' '));

    });

  };

  /*
   * Get host only adapter that mathes our Kalabox host ip
   */
  var getHostOnlyAdapter = function() {
    // Grab all our HO adapters
    return getWindowsAdapters()

    // Grab the adapter that has our host ip
    .then(function(adapters) {
      return _.find(adapters, function(adapter) {
        return adapter.ipaddress === MACHINE_CONFIG.host;
      });
    });
  };

  /*
   * Set up sharing on Linux
   */
  var hasRogueAdapter = function() {

    // Grab the HOA
    return getHostOnlyAdapter()

    // Determine whether it has GONE ROGUE or not
    .then(function(hostAdapter) {

      // Get the kalabox adapter
      return getKalaboxAdapter()

      // Check to see if that adapter is the same as the one
      // that has our host ip
      .then(function(kboxAdapter) {
        var hasAdapter = hostAdapter !== undefined;
        var goneRogue = hasAdapter && kboxAdapter !== hostAdapter.name;
        return (goneRogue) ? hostAdapter : false;
      });
    });

  };

  /*
   * Kill an adapter
   */
  var killAdapter = function(adapter) {

    // Command to run
    var cmd = [
      getVboxExec(),
      'hostonlyif remove "' + adapter.name + '"'
    ];

    // Debug log output
    kbox.core.log.debug('KILLING ADAPTER => ' + JSON.stringify(cmd));

    // Run an elevated command for this
    return kbox.util.shell.execElevated(cmd.join(' '))

    // We need a long delay here to make sure the adapter is actually
    // purged
    .delay(25 * 1000);

  };

  /*
   * Set up sharing on Linux
   */
  var verifyWindowsNetworking = function() {

    // Check to see if we have a rogue adapter
    return hasRogueAdapter()

    // Kill the rogue adapter if we need to
    .then(function(goneRogue) {
      if (goneRogue !== false) {
        return killAdapter(goneRogue);
      }
    })

    // Check if we need to repair our networking
    .then(function() {
      return isHostOnlySet();
    })

    // If not set then set
    .then(function(isSet) {
      if (!isSet) {
        return setHostOnly();
      }
    });
  };

  // Build module function.
  return {
    isHostOnlySet: isHostOnlySet,
    setHostOnly: setHostOnly,
    verifyWindowsNetworking: verifyWindowsNetworking,
    setHostDnsResolver: setHostDnsResolver
  };

};
