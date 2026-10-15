# Sammasak Skills

Reusable agent skills for software development and homelab workflows. The repository can be installed through each harness's native plugin marketplace, or delivered reproducibly with Nix.

## Claude Code

Add the marketplace and install the plugin:

```sh
claude plugin marketplace add sammasak/skills
claude plugin install sammasak-skills@sammasak-skills
```

Inside a Claude Code session, the equivalent commands are `/plugin marketplace add sammasak/skills` and `/plugin install sammasak-skills@sammasak-skills`.

## Cursor

Cursor supports the portable Agent Plugins package in the root `plugin.json`. Add the repository marketplace, then install the plugin from Cursor's Plugins view:

```sh
agent plugin marketplace add https://github.com/sammasak/skills
```

In Cursor, open **Customize → Plugins**, select the `sammasak-skills` marketplace, and install the plugin.

## GitHub Copilot CLI

Copilot CLI reads the shared marketplace manifest in `.claude-plugin/marketplace.json` and the portable root `plugin.json`:

```sh
copilot plugin marketplace add sammasak/skills
copilot plugin install sammasak-skills@sammasak-skills
```

## Codex

Add the marketplace and install the plugin:

```sh
codex plugin marketplace add sammasak/skills
codex plugin add sammasak-skills@sammasak-skills
```

Codex installs the portable skills from the repository's root `skills/` directory. Claude-specific agents and hooks remain available through the Claude Code plugin.

## Gemini CLI

Gemini CLI installs one skill at a time. Replace `nix-flake-development` with the skill directory you want:

```sh
gemini skills install https://github.com/sammasak/skills.git --path skills/nix-flake-development
```

Use `gemini skills list` to verify the installed skill.

## Nix

The NixOS Home Manager integration remains available for atomic, reproducible deployment. See the project configuration that consumes this repository as the `skills` flake input.

## License

This project is licensed under the MIT License; see [LICENSE](LICENSE).
