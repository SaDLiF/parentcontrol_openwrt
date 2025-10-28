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

        // --- Debug флажок сверху ---
        const configSection = m.section(form.NamedSection, 'config', 'parentalcontrol', _('Settings'));
        configSection.anonymous = true;
        const debugFlag = configSection.option(form.Flag, 'debug', _('Enable debug'));
        debugFlag.default = '1';
        debugFlag.rmempty = false;

        // --- Основная таблица правил ---
        const s = m.section(form.GridSection, 'rule', _('Rules'));
        s.anonymous = true;
        s.addremove = true;
        s.sortable = true;

        // Название
        let o = s.option(form.Value, 'name', _('Name'));
        o.rmempty = false;

        // Статус (включено/выключено)
        o = s.option(form.DummyValue, 'enabled', _('Status'));
        o.cfgvalue = (section_id) => {
            const val = uci.get('parentalcontrol', section_id, 'enabled');
            return val === '1' ? '✅' : '❌';
        };

        // MAC
        o = s.option(form.Value, 'mac', _('MAC'));
        o.datatype = 'macaddr';
        Object.keys(hosts).forEach(mac => {
            o.value(mac, '%s (%s)'.format(mac, hosts[mac].name || hosts[mac].ipv4 || ''));
        });

        // IP
        o = s.option(form.Value, 'ip', _('IP'));
        o.datatype = 'ipaddr';
        Object.keys(hosts).forEach(mac => {
            if (hosts[mac].ipv4)
                o.value(hosts[mac].ipv4, '%s (%s)'.format(hosts[mac].ipv4, hosts[mac].name || mac));
        });

        // Дни недели
        o = s.option(form.MultiValue, 'days', _('Days'));
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
