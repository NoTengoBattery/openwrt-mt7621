//
// Copyright (C) 2019-2020 Oever González <notengobattery@gmail.com>
//
// Licensed to the public under the Apache License 2.0.
//

'use strict';
'require form';
'require fs';
'require rpc';

var callInitList;

callInitList = rpc.declare({
	object: 'luci',
	method: 'getInitList',
	params: [ 'name' ],
	expect: { '': {} },
	filter: function(res) {
		for (var k in res)
			return +res[k].enabled;
		return null;
	}
});

function compressors (o) {
	o.value('lz4', 'lz4');
	o.value('lzo_rle', 'lzo-rle');
	o.value('lzo', 'lzo');
	o.value('lz4hc', 'lz4hc');
	o.value('zstd', 'zstd');
	o.value('deflate', 'deflate');
}

function zpool (o) {
	o.value('zbud',   'zbud (ratio: 2.00)');
	o.value('z3fold', 'z3fold (ratio: 3.00)');
}

return L.view.extend({
	load: function() {
		return Promise.all([
			callInitList('zram'),
			callInitList('zswap'),
			L.resolveDefault(fs.stat('/bin/zram'), null),
			L.resolveDefault(fs.stat('/bin/zswap'), null),
			L.resolveDefault(fs.stat('/etc/config/compressed_memory'), null)
		]);
	},
	render: function(loaded) {
		var m, s, o;
		// Don't laugh at me... I don't like JavaScript!
		var zr	= !!loaded[0] & !!loaded[2] & !!loaded[4];
		var zs	= !!loaded[1] & !!loaded[3] & !!loaded[4];

		m = new form.Map('compressed_memory',
			_('Compressed memory subsystem'),
			_('Configure the compressed memory subsystem, which allows data in memory to be compressed to enhance resource usage.'));

		if (zr) {
			s = m.section(form.NamedSection, 'zram', 'params',
				_('Compressed RAM disk properties'),
				_('Configure the compressed RAM disk properties. This RAM disk will be used as a swap device.'));
			s.anonymous	= true;

			o = s.option(form.Flag, 'enabled', _('Enable swap on zram'),
				_('Enable usage of the compressed RAM disk (zram).'));
			o.default	= true;
			o.rmempty	= false;

			o = s.option(form.ListValue, 'algorithm', _('Compression algorithm'),
				_('Select the compression algorithm, the fastest is the first and the slower the last.'));
			compressors(o);
			o.default	= 'lzo_rle'
			o.depends('enabled', '1');
			o.rmempty	= false;

			o = s.option(form.Value, 'pool_base', _('Base memory pool'),
				_('This is the maximum percentage of the main memory to use as the compressed disk, when the data is compressible.'));
			o.datatype	= 'and(ufloat,max(100.00))';
			o.default	= '40.00'
			o.depends('enabled', '1');
			o.rmempty	= false;

			o = s.option(form.Value, 'backing_file', _('Backing storage device'),
				_('This file will be used when the data is hard to compress, which offer no gain to keep it in memory. Note that the file or device must have the appropiate size (for example, the size of the system RAM) and it\'s contents will be destroyed.'));
			o.datatype	= 'or(device,file)'
			o.depends('enabled', '1');
			o.optional	= true;
			o.placeholder	= '/data/zram.img'
			o.rmempty	= false;

			o = s.option(form.Flag, 'advanced', _('Show advanced setup'));
			o.default	= false;
			o.depends('enabled', '1');
			o.rmempty	= false;

			o = s.option(form.Value, 'pool_limit', _('Absolute memory pool limit'),
				_('This is the hard limit of the memory pool, in percentage, scaled by the worst compression ratio.'));
			o.datatype	= 'and(ufloat,max(500.00))';
			o.default	= '96.6183575'
			o.depends('advanced', '1');
			o.rmempty	= false;
		}

		if (zs) {
			s = m.section(form.NamedSection, 'zswap', 'params',
				_('Compressed swap cache properties'),
				_('Configure the compressed swap cache. This cache will try to avoid expensive I/O, or to use the more expensive compressor of zram, when the system is under memory pressure.'));
			s.anonymous	= true;

			o = s.option(form.Flag, 'enabled', _('Enable zswap cache'),
				_('Enable the usage of the compressed swap cache (zswap).'));
			o.default	= true;
			o.rmempty	= false;

			o = s.option(form.ListValue, 'algorithm', _('Compression algorithm'),
				_('Select the compression algorithm, the fastest is the first and the slower the last. There is no gain in choose a slower algorithm because the zpool limits the maximum compression ratio.'));
			compressors(o);
			o.default	= 'lzo_rle'
			o.depends('enabled', '1');
			o.rmempty	= false;

			o = s.option(form.Value, 'pool', _('Maximum memory pool'),
				_('This is the maximum percentage of the main memory to use as the compressed cache for swap when zram is not available.'));
			o.datatype	= 'and(ufloat,max(100.00))';
			o.default	= '30.00'
			o.depends('enabled', '1');
			o.rmempty	= false;

			o = s.option(form.ListValue, 'zpool', _('Memory allocator'),
				_('Select the compressed memory allocator (zpool). This allocator limits the compression ratio of the algorithm.'));
			zpool(o);
			o.default	= 'z3fold'
			o.depends('enabled', '1');
			o.rmempty	= false;

			o = s.option(form.Flag, 'advanced', _('Show advanced setup'));
			o.default	= false;
			o.depends('enabled', '1');
			o.rmempty	= false;

			o = s.option(form.Value, 'swappiness', _('System swappiness'),
				_('This is tendency of the system to swap unused pages instead of dropping file system cache.'));
			o.datatype	= 'and(uinteger,max(100))';
			o.default	= '100'
			o.depends('advanced', '1');
			o.rmempty	= false;

			if (zr) {
				o = s.option(form.ListValue, 'compressor_scale', _('Compressor for zram'),
					_('Select the compression algorithm for zram when zswap is enabled, the worst is the first and the best the last. You probably want to enable a better algorithm that will be used when zswap is getting full or when pages are harder to compress. zram can do a better job with a slower but better compression algorithm.'));
				compressors(o);
				o.default	= 'zstd'
				o.depends('advanced', '1');
				o.rmempty	= false;

				o = s.option(form.Value, 'zswap_scale_pool', _('Scale factor'),
					_('This is the percentage that will underestimate the zswap pool when zram is enabled. This represents the uncompressed data size as a percentage of the zram pool maximum possible size.'));
				o.datatype	= 'and(ufloat,max(100.00))';
				o.default	= '30.00'
				o.depends('advanced', '1');
				o.rmempty	= false;
			}
		}

		return m.render();
	}
});
