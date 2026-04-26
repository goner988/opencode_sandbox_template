## OpenCode sbx sandbox image
A custom OpenCode sandbox image for Docker Sandboxes (`sbx`) with a practical developer toolchain, optional Serena support, and built-in bridge scripts for local LLM workflows.
This project is licensed under the **Apache License 2.0**. See `LICENSE`.
## Third-party software
This project is licensed under the Apache License 2.0.
OpenCode is an independent open source project licensed separately upstream. This repository does not vendor OpenCode source code or distribute prebuilt images containing OpenCode; it provides build instructions and configuration for creating a local OpenCode sandbox image. If you redistribute a built image that includes OpenCode, review and comply with OpenCode's upstream license terms, including any attribution or license notice requirements.
Serena support is optional. Serena is an independent open source project licensed separately upstream. This project does not vendor or redistribute Serena; it only provides an optional build path that lets users install Serena into their own generated image when `SERENA_VERSION` is configured. If you redistribute a built image that includes Serena, review and comply with Serena's upstream license terms.
## What this image provides
This image builds an OpenCode-ready sandbox from Ubuntu and installs a developer environment suitable for agentic coding workflows:
- OpenCode, launched through `bun x`
- Node.js, Bun, Python, `uv`, `uvx`, Go, Git, `ripgrep`, `jq`, Make, editors, and common CLI tools
- A non-root `agent` user
- OpenCode configuration copied into the image at build time
- Optional Serena installation
- Optional Serena MCP server configuration
- A localhost bridge for host-side local model servers
- A Qwen3.x bridge for separating tagged reasoning from normal response content
The image is intended to be used with Docker Sandboxes through the newer `sbx` CLI.
> This README intentionally uses `sbx` examples only. It does not use the older `docker sandbox ...` interface.
## Repository layout
Expected project structure:
```text
.
├── Dockerfile
├── LICENSE
├── Makefile
├── bashrc.sandbox
├── entrypoint.sh
├── sandbox-persistent.sh
├── docker
│   ├── configs
│   │   ├── opencode.json
│   │   ├── opencode_serena.json
│   │   └── versions.env
│   └── scripts
│       ├── qwen-cot-bridge.js
│       └── sandbox-localhost-bridge.js
└── scripts
    ├── build-arm64.sh
    ├── build-arm64-sbx.sh
    └── run-local.sh
```
The following files are intentionally user/project-local configuration files and should be created by you:
- `docker/configs/opencode.json`
- `docker/configs/versions.env`
- `docker/configs/opencode_serena.json`, only if you want the Serena-enabled image variant
These files are not provided as universal defaults because they may contain user-specific model names, provider choices, local endpoints, placeholder environment variable names, or other settings that differ per machine and project.
## Important build-time requirement
`docker/configs/opencode.json` must exist before building the image.
The Dockerfile copies the OpenCode config into the image during the build. You can still edit or replace the config later inside a created sandbox, but the file must be present when the image is built.
Create the config directory first:
```bash
mkdir -p docker/configs
```
Then provide your OpenCode config:
```bash
cp path/to/your/opencode.json docker/configs/opencode.json
```
If you want to build the Serena-enabled variant, also provide:
```bash
cp path/to/your/opencode_serena.json docker/configs/opencode_serena.json
```
The Dockerfile expects the underscore filename:
```text
docker/configs/opencode_serena.json
```
If you prefer a hyphenated name such as `opencode-serena.json`, adjust the Dockerfile accordingly before building.
## Build profile and variants
The build scripts read versions from:
```text
docker/configs/versions.env
```
Create this file yourself.
Base variant example:
```env
UV_VERSION=0.9.11
NODE_VERSION=24.11.1
BUN_VERSION=1.3.11
OPENCODE_VERSION=1.3.7
```
Serena variant example:
```env
UV_VERSION=0.9.11
NODE_VERSION=24.11.1
BUN_VERSION=1.3.11
OPENCODE_VERSION=1.3.7
SERENA_VERSION=0.2.0
```
The build profile is selected by `SERENA_VERSION`:
- If `SERENA_VERSION` is unset or empty, the image is tagged as `base`.
- If `SERENA_VERSION` is set, the image is tagged as `serena` and Serena is installed during the Docker build.
## Build the image
### Build a local Docker image
```bash
./scripts/build-arm64.sh
```
This builds one of the following tags:
```text
local/sandbox-opencode-local:base
```
or:
```text
local/sandbox-opencode-local:serena
```
### Build and load into sbx
```bash
./scripts/build-arm64-sbx.sh
```
This script:
1. Builds the image with Docker Buildx.
2. Saves the image to a temporary tar file.
3. Loads the image into the sbx template store with `sbx template load`.
4. Removes the temporary tar file.
This is the recommended build path when you want to use the image directly as an sbx template.
## Using the image with sbx
Create a sandbox from the base template with the current directory as the workspace:
```bash
sbx create \
  --name my-opencode-sbx \
  --template local/sandbox-opencode-local:base \
  opencode .
```
Create a sandbox from the Serena-enabled template:
```bash
sbx create \
  --name my-opencode-sbx \
  --template local/sandbox-opencode-local:serena \
  opencode .
```
Run an existing sandbox:
```bash
sbx run my-opencode-sbx
```
Open a shell inside the sandbox:
```bash
sbx exec -it my-opencode-sbx bash
```
Remove the sandbox:
```bash
sbx rm my-opencode-sbx
```
Use `--force` for non-interactive cleanup:
```bash
sbx rm --force my-opencode-sbx
```
List sandboxes:
```bash
sbx ls
```
## Network access to host localhost
Docker Sandboxes apply network policy. If OpenCode inside the sandbox should call a model server running on your host machine, allow access to the host-side port immediately after creating the sandbox.
Example for a host-side LLM server on port `11434`:
```bash
sbx policy allow network my-opencode-sbx localhost:11434
```
Use the actual host port of your LLM server.
This is required for local-model workflows where the sandbox needs to reach a server running on the host. The sandbox should not assume it can access arbitrary host services unless the sbx network policy allows it.
## Built-in local-model support
OpenCode supports local models through OpenAI-compatible providers. This image includes a bridge script to make host-side local model servers easier to use from inside an sbx sandbox:
```text
docker/scripts/sandbox-localhost-bridge.js
```
The bridge listens inside the sandbox on:
```text
http://127.0.0.1:54321
```
and forwards requests through the sandbox/host proxy to a host-side local model server at:
```text
localhost:11434
```
That default target is useful for Ollama-compatible local servers.
If your host-side LLM server uses a different port, update the `TARGET` value in:
```text
docker/scripts/sandbox-localhost-bridge.js
```
before building the image.
For example, change:
```js
const TARGET = "localhost:11434";
```
to:
```js
const TARGET = "localhost:1234";
```
Then allow the matching host port after creating the sandbox:
```bash
sbx policy allow network my-opencode-sbx localhost:1234
```
In `opencode.json`, point the local provider endpoint to the bridge inside the sandbox:
```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "local": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Local model server",
      "options": {
        "baseURL": "http://127.0.0.1:54321/v1",
        "apiKey": "ollama"
      },
      "models": {
        "qwen3-local": {
          "name": "Qwen3 local",
          "tool_call": true,
          "reasoning": true,
          "limit": {
            "context": 131072,
            "output": 8192
          }
        }
      }
    }
  },
  "model": "local/qwen3-local"
}
```
### Why use local models with this image?
Using locally hosted models gives you a practical middle ground:
- You can run the agent in an isolated sandbox while keeping the model server on your host.
- You can avoid sending code and prompts to an external inference provider.
- You can experiment without per-token API costs.
- You can use local models with larger context windows when your hardware supports them.
- You can switch between cloud providers and local providers by editing `opencode.json`.
- You can keep sandbox network access explicit and narrow through `sbx policy allow network`.
The sandbox provides an isolated workspace and controlled network access, while the host machine runs the heavier model-serving process.
## Qwen3.x chain-of-thought bridge
This project includes a second working bridge:
```text
docker/scripts/qwen-cot-bridge.js
```
Its purpose is to support Qwen3.x-style responses from providers that return reasoning inline in normal message content, usually containing only a closing thinking tag, such as:
```text
...</think>
```
or:
```text
...</thinking>
```
The bridge listens on:
```text
http://127.0.0.1:8500
```
It forwards requests to a configured upstream HTTPS provider host and, only for models whose request model name contains `qwen3.`, attempts to move tagged thinking text into `reasoning_content` while leaving the normal user-visible response in `content`.
That allows OpenCode and compatible tooling to treat reasoning and normal answer text as separate fields when the upstream provider does not already provide native reasoning fields.
To use this bridge, configure the provider endpoint in `opencode.json` to point to the bridge:
```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "qwen-bridge": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Qwen bridge",
      "options": {
        "baseURL": "http://127.0.0.1:8500/v1",
        "apiKey": "{env:MY_SAFE_PLACEHOLDER_KEY}"
      },
      "models": {
        "qwen3.example-model": {
          "name": "Qwen3 example model",
          "reasoning": true,
          "tool_call": true,
          "limit": {
            "context": 131072,
            "output": 8192
          }
        }
      }
    }
  },
  "model": "qwen-bridge/qwen3.example-model"
}
```
Before building, set the upstream host in:
```text
docker/scripts/qwen-cot-bridge.js
```
The script contains:
```js
const TARGET_HOST = 'HOST_URL_PLACEHOLDER';
```
Change it to the upstream provider host:
```js
const TARGET_HOST = 'api.example-llm-provider.com';
```
Do not include `https://` in `TARGET_HOST`; the bridge uses HTTPS internally and forwards to port `443`.
## Secrets with sbx
Avoid hardcoding API keys into `opencode.json`.
OpenCode supports environment-variable references in config values, for example:
```json
"apiKey": "{env:MY_SAFE_PLACEHOLDER_KEY}"
```
Docker Sandboxes can store secrets outside the sandbox and patch them into outbound requests on the fly. With custom secrets, the sandbox sees only a placeholder value. When a request to the configured host contains that placeholder, the sbx proxy replaces it with the real secret before the request leaves the host.
Important details:
- The secret must exist before creating a sandbox that should use it.
- Global secrets apply to newly created sandboxes.
- If you add or change a global secret after creating a sandbox, recreate the sandbox for that sandbox to receive it.
- The real secret should not be placed in `opencode.json`.
- Prefer sbx stored secrets over plaintext environment variables.
### Create a custom secret
Example for an LLM inference provider at `api.example-llm-provider.com`:
```bash
sbx secret set-custom -g \
  --host api.example-llm-provider.com \
  --env MY_SAFE_PLACEHOLDER_KEY \
  --value "REPLACE_WITH_REAL_SECRET"
```
On macOS, a better pattern is to copy the key to the clipboard and use `pbpaste`, so the actual key is not written directly into your terminal command history:
```bash
sbx secret set-custom -g \
  --host api.example-llm-provider.com \
  --env MY_SAFE_PLACEHOLDER_KEY \
  --value "$(pbpaste)"
```
Then reference it in `opencode.json`:
```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "myprovider": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "My provider",
      "options": {
        "baseURL": "https://api.example-llm-provider.com/v1",
        "apiKey": "{env:MY_SAFE_PLACEHOLDER_KEY}"
      },
      "models": {
        "my-model": {
          "name": "My model"
        }
      }
    }
  },
  "model": "myprovider/my-model"
}
```
Inside the sandbox, `MY_SAFE_PLACEHOLDER_KEY` is not the real API key. It is a placeholder that sbx can replace on outbound requests to the configured host.
### Remove a custom secret
Custom secret support is experimental in sbx. The documented removal pattern for a custom secret is host-based:
```bash
sbx secret rm -g --host api.example-llm-provider.com
```
List stored secrets with:
```bash
sbx secret ls
```
## Optional Serena support
Serena is a coding-agent toolkit that provides semantic code retrieval and editing capabilities through MCP.
This project provides optional build-time support for Serena. The Dockerfile can download and install Serena into the user-generated image when you provide a `SERENA_VERSION` in:
```text
docker/configs/versions.env
```
Example:
```env
SERENA_VERSION=0.2.0
```
When `SERENA_VERSION` is set, the Dockerfile installs Serena from its upstream project at the requested version.
See [Third-party software](#third-party-software) for licensing and redistribution notes.
## Configure OpenCode for Serena
For the Serena variant, provide a Serena-aware OpenCode config before building:
```text
docker/configs/opencode_serena.json
```
The Dockerfile uses `opencode_serena.json` as the image’s OpenCode config when `SERENA_VERSION` is set.
OpenCode configures MCP servers under the top-level `mcp` key. For Serena, the config should define a local MCP server that starts Serena from the installed binary inside the image.
A minimal `opencode_serena.json` can look like this:
```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "serena": {
      "type": "local",
      "enabled": true,
      "command": [
        "/home/agent/.local/bin/serena",
        "start-mcp-server",
        "--project-from-cwd"
      ],
      "timeout": 25000
    }
  },
  "provider": {
    "local": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Local model server",
      "options": {
        "baseURL": "http://127.0.0.1:54321/v1",
        "apiKey": "ollama"
      },
      "models": {
        "qwen3-local": {
          "name": "Qwen3 local",
          "tool_call": true,
          "reasoning": true,
          "limit": {
            "context": 131072,
            "output": 8192
          }
        }
      }
    }
  },
  "model": "local/qwen3-local"
}
```
The important Serena MCP part is:
```json
"mcp": {
  "serena": {
    "type": "local",
    "enabled": true,
    "command": [
      "/home/agent/.local/bin/serena",
      "start-mcp-server",
      "--project-from-cwd"
    ],
    "timeout": 25000
  }
}
```
This tells OpenCode to start Serena as a local MCP server from the current working directory. The `--project-from-cwd` argument makes Serena use the current repository/workspace as the project context.
### Initialize Serena for a repository
The image wrapper checks the workspace `.env` file.
If the workspace `.env` contains:
```env
INIT_SERENA_IN_REPO=1
```
then the image attempts to initialize Serena for that repository when OpenCode starts.
The wrapper runs Serena initialization only when the Serena-enabled image variant is used.
## Included bridge scripts
This project includes two working JavaScript bridge scripts.
### `sandbox-localhost-bridge.js`
Purpose:
- Make a host-side local LLM server reachable from OpenCode inside the sandbox.
- Default sandbox endpoint: `http://127.0.0.1:54321/v1`
- Default host target: `localhost:11434`
- Useful for Ollama-style OpenAI-compatible local servers.
Change the host target port in the script if your host model server does not use `11434`.
### `qwen-cot-bridge.js`
Purpose:
- Proxy HTTPS requests to an upstream LLM provider.
- Detect Qwen3.x model calls.
- Split tagged reasoning text from normal answer content when the provider returns thinking in `<think>` or `<thinking>` tags.
- Expose that reasoning as `reasoning_content` for clients that understand separate reasoning fields.
Use this when your Qwen3.x provider does not already return native reasoning fields but you want OpenCode to receive reasoning separately from final answer text.
## Example OpenCode config for local models
```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "mlx": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "MLX local",
      "options": {
        "baseURL": "http://127.0.0.1:54321/v1",
        "apiKey": "ollama"
      },
      "models": {
        "qwen3-local": {
          "name": "Qwen3 local",
          "tool_call": true,
          "reasoning": true,
          "limit": {
            "context": 131072,
            "output": 8192
          },
          "options": {
            "temperature": 0.1,
            "top_p": 0.95
          }
        }
      }
    }
  },
  "model": "mlx/qwen3-local",
  "small_model": "mlx/qwen3-local"
}
```
For this config, the host model server should listen on the port configured in `sandbox-localhost-bridge.js`, and the sandbox policy must allow that host port:
```bash
sbx policy allow network my-opencode-sbx localhost:11434
```
## Example OpenCode config for a remote OpenAI-compatible provider with sbx secrets
```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "myprovider": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "My provider",
      "options": {
        "baseURL": "https://api.example-llm-provider.com/v1",
        "apiKey": "{env:MY_SAFE_PLACEHOLDER_KEY}"
      },
      "models": {
        "my-model": {
          "name": "My model",
          "tool_call": true,
          "reasoning": true,
          "limit": {
            "context": 131072,
            "output": 8192
          }
        }
      }
    }
  },
  "model": "myprovider/my-model"
}
```
Create the matching sbx secret before creating the sandbox:
```bash
sbx secret set-custom -g \
  --host api.example-llm-provider.com \
  --env MY_SAFE_PLACEHOLDER_KEY \
  --value "$(pbpaste)"
```
Then create the sandbox:
```bash
sbx create \
  --name my-opencode-sbx \
  --template local/sandbox-opencode-local:base \
  opencode "$PWD"
```
## Example Serena-enabled OpenCode config
This example combines Serena MCP support with the local model bridge:
```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "serena": {
      "type": "local",
      "enabled": true,
      "command": [
        "/home/agent/.local/bin/serena",
        "start-mcp-server",
        "--project-from-cwd"
      ],
      "timeout": 25000
    }
  },
  "provider": {
    "mlx": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "MLX local",
      "options": {
        "baseURL": "http://127.0.0.1:54321/v1",
        "apiKey": "ollama"
      },
      "models": {
        "Qwen3.5-35B-A3B-6bit": {
          "name": "Qwen3.5 35B A3B",
          "tool_call": true,
          "reasoning": true,
          "limit": {
            "context": 131072,
            "output": 83968
          },
          "options": {
            "temperature": 0.1,
            "top_p": 0.95,
            "top_k": 20,
            "min_p": 0,
            "presence_penalty": 0,
            "repeat_penalty": 1
          }
        },
        "Qwen3.5-4B-MLX-4bit": {
          "name": "Qwen3.5 4B",
          "tool_call": false,
          "reasoning": true,
          "limit": {
            "context": 131072,
            "output": 1024
          },
          "options": {
            "temperature": 0.6,
            "top_p": 0.95,
            "top_k": 20,
            "min_p": 0,
            "presence_penalty": 0,
            "repeat_penalty": 1
          }
        },
        "gemma-4-26b-a4b-it-8bit": {
          "name": "Gemma 4 26B A4B 8Bit",
          "tool_call": true,
          "reasoning": true,
          "limit": {
            "context": 131072,
            "output": 16384
          },
          "options": {
            "temperature": 1.0,
            "top_p": 0.95,
            "top_k": 64
          }
        }
      }
    }
  },
  "model": "mlx/gemma-4-26b-a4b-it-8bit",
  "small_model": "mlx/Qwen3.5-4B-MLX-4bit"
}
```
Use this as a starting point only. Adjust provider names, model IDs, model limits, and local endpoint ports to match your own host-side model server.
## Troubleshooting
### Build fails because config files are missing
Create the required files:
```bash
mkdir -p docker/configs
touch docker/configs/opencode.json
touch docker/configs/versions.env
```
If building the Serena variant, also create:
```bash
touch docker/configs/opencode_serena.json
```
### Local model server cannot be reached
Check all of the following:
1. The host-side model server is running.
2. The host-side model server port matches `TARGET` in `sandbox-localhost-bridge.js`.
3. The OpenCode provider `baseURL` points to the in-sandbox bridge, usually `http://127.0.0.1:54321/v1`.
4. The sbx network policy allows the host port:
```bash
sbx policy allow network my-opencode-sbx localhost:11434
```
### Secret is not being patched
Check all of the following:
1. The secret was created before the sandbox was created.
2. The `--host` value matches the provider host being called.
3. The `--env` value matches the `{env:...}` placeholder in `opencode.json`.
4. The request actually contains the placeholder value.
5. If you changed a global secret after sandbox creation, recreate the sandbox.
### Open a debug shell
```bash
sbx exec -it my-opencode-sbx bash
```
Useful checks inside the sandbox:
```bash
which opencode
node --version
bun --version
uv --version
cat ~/.config/opencode/opencode.json
```
## Notes
- The project uses Apache License 2.0.
- Serena support is optional and user-enabled through `SERENA_VERSION`.
- Serena is an open source project and has its own upstream license.
- This repository does not distribute Serena directly; it only provides an optional build path that downloads Serena into the generated image.
- User-specific OpenCode config files are intentionally not treated as universal defaults.
- `scripts/run-local.sh` is optional and mainly useful for local experiments outside sbx.
- Prefer the `sbx` workflow for actual sandbox use.
- Inspired by the project docker-sandbox-run-copilot: https://github.com/henrybravo/docker-sandbox-run-copilot
- The local-model networking approach was also inspired by the Docker/OpenClaw sandbox example that allows sandbox access to the host's localhost for locally hosted models and uses a small bridge to forward requests from inside the sandbox to the host-side model server: https://www.linkedin.com/pulse/run-openclaw-securely-docker-sandboxes-docker-cftjc
