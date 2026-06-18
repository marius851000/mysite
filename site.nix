#TODO: translation

{ pkgs ? import <nixpkgs> {}}:

with pkgs.lib.strings;

let
  util = import ./nix/util.nix { pkgs = pkgs; };
  generic_pagegen = import ./nix/generic_pagegen.nix { inherit util pkgs; };
  blog = import ./nix/blog.nix { inherit util pkgs generic_pagegen; };

  #path should not end with a slash
  buildSectionFromStructure = structure: path:
    let
      instructionsList = (pkgs.lib.map
        (content: let
        info = if (pkgs.lib.isDerivation content) then
          {
            input = content;
            output = "$out/${content.path}";
          }
        else
          throw "unsupported content type in site structure, expected a function: ${builtins.toString content}";
        in info)
      )
      structure;

      instructions = builtins.toJSON instructionsList;
    in
      pkgs.stdenv.mkDerivation {
        name = "site-a-structure";

        phases = "installPhase";

        nativeBuildInputs = [ pkgs.python3 pkgs.rsync ];

        installPhase = ''
          set -x
          mkdir -p $out
          echo ${pkgs.lib.escapeShellArg instructions} > instructions.json
          substituteInPlace instructions.json --replace "\$out" "$out"
          cat instructions.json
          ${pkgs.python3}/bin/python3 ${./process_result.py} instructions.json

          export SITEMAP_GIT_ROOT="$PWD"

          python3 ${./generate_sitemap.py} $out -u https://mariusdavid.fr -o $out/sitemap.xml

          set +x
        '';
      };


  structure = import ./structure.nix {
    inherit buildPage;
    buildBlogIndex = blog.buildBlogIndex;
    buildArticlePage = blog.buildArticlePage;
    buildBlog = blog.buildBlog;
    buildStaticFile = util.buildStaticFile;
  };
in
  buildSectionFromStructure structure ""
