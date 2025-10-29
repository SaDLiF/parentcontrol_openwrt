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

        // --- Основная таблица правил ---
        const s = m.section(form.GridSection, 'rule', _('Rules'));
        s.anonymous = true;
        s.addremove = true;
        s.sortable = true;

        // Включено (флажок для управления)
        let o = s.option(form.Flag, 'enabled', _('Enabled'));
        o.default = '1';
        o.rmempty = false;

        // Название
        o = s.option(form.Value, 'name', _('Name'));
        o.rmempty = false;

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

        // Дни недели
        o = s.option(form.MultiValue, 'days', _('Weekdays'));
        ['mon','tue','wed','thu','fri','sat','sun'].forEach(day => o.value(day, _(day.toUpperCase())));
        o.default = 'mon tue wed thu fri';
        o.rmempty = false;

        // Время начала
        o = s.option(form.Value, 'start', _('Start'));
        o.datatype = 'time';
        o.placeholder = 'HH:MM';
        o.default = '21:00';
        o.rmempty = false;

        // Время окончания
        o = s.option(form.Value, 'end', _('End'));
        o.datatype = 'time';
        o.placeholder = 'HH:MM';
        o.default = '07:00';
        o.rmempty = false;

        return m.render();
    }
});
