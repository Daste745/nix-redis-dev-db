# Nix Redis Dev DB

This flake is a simple wrapper around redis-server that provides scripts to start and stop a development Redis server. All data is stored in a user-configurable directory and is not persisted across sessions.

## Packages

Following packages are available inside this flake's outputs:

- `start-redis` starts a Redis server inside `$REDIS_DATA` on port `$REDIS_PORT` (default: 6379)
- `stop-redis` stops the Redis server

## Usage in a dev shell

1. Add `github:Daste745/nix-redis-dev-db` as an input
2. Add `start-redis` and `stop-redis` to your dev shell's `packages`
3. Add a redis package to your dev shell's `packages`
4. Export `REDIS_DATA` and `REDIS_PORT` (optional) to your shell (e.g. using a shellHook)
5. Use `start-redis` to start the Redis server and `stop-redis` to stop it

Example flake for x86_64-linux. This can be expanded to other systems as well.

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    redis-dev-db = {
      url = "github:Daste745/nix-redis-dev-db";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs { inherit system; };
      redis-dev-db = inputs.redis-dev-db.outputs.packages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.redis
          redis-dev-db.start-redis
          redis-dev-db.stop-redis
        ];
        shellHook = ''
          # If the directory is not tracked by git, swap this for the absolute path to the directory
          export REDIS_DATA=$(git rev-parse --show-toplevel)/REDIS_DATA
          # Optional - default is 6379
          export REDIS_PORT=6379
        '';
      };
    };
}
```
