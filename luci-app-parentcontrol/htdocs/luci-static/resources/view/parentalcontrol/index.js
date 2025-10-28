'use strict';
'require rpc';
'require uci';
'require form';
'require view';

const VERSION = "__COMPILED_VERSION_VARIABLE__";

const callHostHints = rpc.declare({
    object: 'luci-rpc',
    method: 'getHostHints',
    expect: { '': {} }
});

return view.extend({
    load: () => Promise.all([
        uci.load('parentalcontrol'),
        callHostHints()
    ]),

    render: (data) => {
        const hosts = data[1];

        const m = new form.Map('parentalcontrol', 
            _('Parental Control %s').format(VERSION),
            _('Configure access rules by MAC/IP')
        );

        const s = m.section(form.GridSection, 'rule', _('Rules'));
        s.anonymous = true;
        s.addremove = true;

        // Name
        let o = s.option(form.Value, 'name', _('Name'));
        o.rmempty = false;

        // Enabled flag with icon
        o = s.option(form.Flag, 'enabled', _('Enabled'));
        o.default = '1';
        o.rmempty = false;
        o.cfgvalue = (section_id) => {
            const val = form.Flag.prototype.cfgvalue(section_id, 'enabled');
            if (val == '1') {
                return '<i class="fa fa-check-circle" style="color:green"></i>';
            }
            return '<i class="fa fa-times-circle" style="color:red"></i>';
        };

        // MAC
        o = s.option(form.Value, 'mac', _('MAC Address'));
        o.datatype = 'macaddr';
        Object.keys(hosts).forEach(mac => {
            o.value(mac, '%s (%s)'.format(mac, hosts[mac].name || hosts[mac].ipv4 || ''));
        });

        // IP
        o = s.option(form.Value, 'ip', _('IP Address'));
        o.datatype = 'ipaddr';
        Object.keys(hosts).forEach(mac => {
            if (hosts[mac].ipv4)
                o.value(hosts[mac].ipv4, '%s (%s)'.format(hosts[mac].ipv4, hosts[mac].name || mac));
        });

        // Weekdays
        o = s.option(form.MultiValue, 'days', _('Weekdays'));
        ['mon','tue','wed','thu','fri','sat','sun'].forEach(d => o.value(d, _(d)));
        o.default = 'mon tue wed thu fri';
        o.rmempty = false;

        // Time start
        o = s.option(form.Value, 'start', _('Start'));
        o.datatype = 'time';
        o.placeholder = 'HH:MM';
        o.default = '21:00';
        o.rmempty = false;

        // Time end
        o = s.option(form.Value, 'end', _('End'));
        o.datatype = 'time';
        o.placeholder = 'HH:MM';
        o.default = '07:00';
        o.rmempty = false;

        return m.render();
    }
});
