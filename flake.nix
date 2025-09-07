{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    {
      self,
      systems,
      nixpkgs,
      ...
    }:
    let
      inherit (nixpkgs.lib) getExe;
      eachSystem =
        f:
        nixpkgs.lib.genAttrs (import systems) (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs { inherit system; };
          }
        );
    in
    {
      packages = eachSystem (
        { pkgs, ... }:
        let
          redis-data-dir = "$REDIS_DATA";
          redis-port = "\${REDIS_PORT:-6379}";
          pid-file = "${redis-data-dir}/redis.pid";
          log-file = "${redis-data-dir}/redis.log";

          check-env = pkgs.writeShellScriptBin "check-env" ''
            set -eu
            if [ -z "${redis-data-dir}" ]; then
              echo "${redis-data-dir} is not set. Please set it in your environment."
              exit 1
            fi
          '';
        in
        {
          start-redis = (
            pkgs.writeShellScriptBin "start-redis" ''
              set -eu
              ${getExe check-env}
              # FIXME: This check can give a false-positive if the PID file is stale (server wasn't stopped properly)
              if [[ -f ${pid-file} ]]; then
                echo "Redis server is already running with PID $(cat ${pid-file})"
                exit 0
              fi
              if [[ ! -d ${redis-data-dir} ]]; then
                echo "Creating Redis data directory: ${redis-data-dir}"
                mkdir -p ${redis-data-dir}
              fi
              touch ${log-file}
              ${pkgs.redis}/bin/redis-server \
                --bind 127.0.0.1 \
                --port ${redis-port} \
                --daemonize yes \
                --dir ${redis-data-dir} \
                --logfile ${log-file} \
                --pidfile ${pid-file}
              echo "Redis server started at ${redis-data-dir}"
            ''
          );

          stop-redis = (
            pkgs.writeShellScriptBin "stop-redis" ''
              set -eu
              ${getExe check-env}
              if [[ ! -f ${pid-file} ]]; then
                echo "Redis server is not running, no PID file found."
                exit 0
              fi
              redis_pid=$(cat ${pid-file})
              echo "Stopping Redis server with PID $redis_pid"
              kill $redis_pid || true
              echo "Redis server stopped."
            ''
          );
        }
      );

      devShells = eachSystem (
        { system, pkgs }:
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.redis
              self.packages.${system}.start-redis
              self.packages.${system}.stop-redis
            ];
            shellHook = ''
              export REDIS_DATA=$(git rev-parse --show-toplevel)/REDIS_DATA
              export REDIS_PORT=63790
            '';
          };
        }
      );
    };
}
