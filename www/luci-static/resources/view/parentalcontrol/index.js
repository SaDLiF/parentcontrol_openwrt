'use strict';
'require rpc';
'require uci';
'require form';
'require view';

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
        const m = new form.Map('parentalcontrol', _('Родительский контроль'), _('Настройка правил доступа по MAC/IP'));

        const s = m.section(form.GridSection, 'rule', _('Правила'));
        s.anonymous = true;
        s.addremove = true;

        // Название
        let o = s.option(form.Value, 'name', _('Название'));
        o.rmempty = false;

        // Включено
        o = s.option(form.Flag, 'enabled', _('Включено'));
        o.default = '1';
        o.rmempty = false;

        // MAC
        o = s.option(form.Value, 'mac', _('MAC-адрес'));
        o.datatype = 'macaddr';
        Object.keys(hosts).forEach(mac => {
            o.value(mac, '%s (%s)'.format(mac, hosts[mac].name || hosts[mac].ipv4 || ''));
        });

        // IP
        o = s.option(form.Value, 'ip', _('IP-адрес'));
        o.datatype = 'ipaddr';
        Object.keys(hosts).forEach(mac => {
            if (hosts[mac].ipv4)
                o.value(hosts[mac].ipv4, '%s (%s)'.format(hosts[mac].ipv4, hosts[mac].name || mac));
        });

        // Дни недели
        o = s.option(form.MultiValue, 'days', _('Дни недели'));
        o.value('mon', _('Пн'));
        o.value('tue', _('Вт'));
        o.value('wed', _('Ср'));
        o.value('thu', _('Чт'));
        o.value('fri', _('Пт'));
        o.value('sat', _('Сб'));
        o.value('sun', _('Вс'));
        o.default = 'mon tue wed thu fri';
        o.rmempty = false;

        // Время начала
        o = s.option(form.Value, 'start', _('Начало'));
        o.datatype = 'time';
        o.placeholder = 'HH:MM';
        o.default = '21:00';
        o.rmempty = false;

        // Время окончания
        o = s.option(form.Value, 'end', _('Окончание'));
        o.datatype = 'time';
        o.placeholder = 'HH:MM';
        o.default = '07:00';
        o.rmempty = false;

        // Добавляем информационную секцию
        const infoSection = m.section(form.NamedSection, '_info', 'info', _('Информация'));
        infoSection.anonymous = true;

        const infoOption = infoSection.option(form.DummyValue, '_notice');
        infoOption.default = _('Правила применяются автоматически при сохранении конфигурации');
        infoOption.rawhtml = true;

	// Добавляем секцию config с флажком debug
const configSection = m.section(form.NamedSection, 'config', 'parentalcontrol', _('Общие настройки'));
configSection.anonymous = true;

const debugFlag = configSection.option(form.Flag, 'debug', _('Включить отладку'));
debugFlag.default = '1';
debugFlag.rmempty = false;


        return m.render();
    }
});
