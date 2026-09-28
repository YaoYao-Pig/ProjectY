// Same uint32 xorshift and ordered catalog as PawnCustomizationRules. Cross-language fixtures come from Unity.
export function options(rules, slot, race, sex) {
  return rules.modules.filter(m => m.slot === slot && (!m.sex || m.sex === sex) &&
    (!m.race || m.race === 'all' || m.race.split(',').includes(race)));
}
export function validate(rules, value) {
  if (!value || value.version !== rules.version || !Number.isInteger(value.seed) || value.seed < 0 || value.seed > 2147483647) throw new Error('外观版本或种子无效');
  const race = rules.races.find(r => r.id === value.race);
  if (!race || !['male', 'female'].includes(value.sex)) throw new Error('未知种族或性别');
  for (const slot of ['body', 'head', 'hair']) if (!options(rules, slot, value.race, value.sex).some(m => m.id === value[slot])) throw new Error(`不兼容的${slot}模块：${value[slot]}`);
  for (const [key, colors] of [['skin', race.colors], ['hairColor', rules.hairColors], ['clothColor', rules.clothColors]])
    if (!Number.isInteger(value[key]) || value[key] < 0 || value[key] >= colors.length) throw new Error('外观颜色索引超出目录');
  return value;
}
export function randomize(rules, seed, race, sex) {
  if (!Number.isInteger(seed) || seed < 0 || seed > 2147483647) throw new Error('种子需为 0–2147483647 的整数');
  let state = seed || 0x6d2b79f5;
  const next = () => { state ^= state << 13; state ^= state >>> 17; state ^= state << 5; return state >>> 0; };
  const value = { version: rules.version, seed, race: race ?? rules.races[next() % rules.races.length].id, sex: sex ?? (next() % 2 === 0 ? 'male' : 'female') };
  for (const slot of ['body', 'head', 'hair']) {
    const candidates = options(rules, slot, value.race, value.sex);
    if (!candidates.length) throw new Error('随机范围没有可用模块');
    value[slot] = candidates[next() % candidates.length].id;
  }
  const palette = rules.races.find(r => r.id === value.race);
  value.skin = next() % palette.colors.length;
  value.hairColor = next() % rules.hairColors.length;
  value.clothColor = next() % rules.clothColors.length;
  return validate(rules, value);
}
export function tint(rules, descriptor, role, fallback) {
  if (role === 'Skin') return rules.races.find(r => r.id === descriptor.race).colors[descriptor.skin];
  if (role === 'Hair') return rules.hairColors[descriptor.hairColor];
  if (role === 'Cloth') return rules.clothColors[descriptor.clothColor];
  return fallback;
}
