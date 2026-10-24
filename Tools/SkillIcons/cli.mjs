import { fileURLToPath } from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';
import { prepare, publish, status, validate } from './pipeline.mjs';

const help = `Skill icon pipeline (offline; image generation uses the built-in image_gen tool)
  node Tools/SkillIcons/cli.mjs list [--skill 1,2 | --all]
  node Tools/SkillIcons/cli.mjs status [--skill 1,2 | --all]
  node Tools/SkillIcons/cli.mjs prepare --skill 1,2 | --all
  node Tools/SkillIcons/cli.mjs publish --skill 1 --image <absolute.png> --job Art/SkillIcons/Jobs/10001.json --reviewed
  node Tools/SkillIcons/cli.mjs validate

--reviewed confirms visual review: real transparent background, obvious skill meaning,
simple silhouette, restrained details, and readable at 32 px and 64 px.
Publishing preserves source PNG bytes and existing versions. It does not create .meta
files, export config, start Unity, refresh assets, or enter Play Mode.`;

export function run(args) {
  const [command, ...flags] = args;
  if (!command || command === '--help' || command === 'help') return help;
  assert(['list', 'status', 'prepare', 'publish', 'validate'].includes(command), `Unknown command: ${command}`);
  const options = {};
  const allowed = command === 'publish' ? ['skill', 'image', 'job', 'reviewed'] : command === 'validate' ? [] : ['skill', 'all'];
  for (let index = 0; index < flags.length; index++) {
    const flag = flags[index];
    assert(flag.startsWith('--') && allowed.includes(flag.slice(2)), `Unknown option for ${command}: ${flag}`);
    const key = flag.slice(2);
    assert(!Object.hasOwn(options, key), `Duplicate option: ${flag}`);
    if (key === 'all' || key === 'reviewed') options[key] = true;
    else {
      const value = flags[++index];
      assert(value && !value.startsWith('--'), `Missing value for ${flag}`); options[key] = value;
    }
  }
  assert(!(options.all && options.skill), 'Choose --all or --skill');
  let skillIds;
  if (options.skill !== undefined) {
    assert(/^[1-9]\d*(?:,[1-9]\d*)*$/.test(options.skill), '--skill requires comma-separated positive IDs');
    skillIds = options.skill.split(',').map(Number);
  }
  if (command === 'prepare') {
    assert(options.all || skillIds, 'prepare requires --skill or --all');
    return prepare({ skillIds });
  }
  if (command === 'publish') {
    assert(skillIds?.length === 1, 'publish requires exactly one --skill');
    return publish({ skillId: skillIds[0], image: options.image, job: options.job, reviewed: options.reviewed });
  }
  if (command === 'validate') return validate();
  return status({ skillIds });
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const result = run(process.argv.slice(2));
    console.log(typeof result === 'string' ? result : JSON.stringify(result, null, 2));
  } catch (error) {
    console.error(`Skill icons: ${error.message}`);
    process.exitCode = 1;
  }
}
