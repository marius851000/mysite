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
      instructionsList = (pkgs.lib.mapAttrsToList
        (key: content: let
        info = if (pkgs.lib.isFunction content) then
          let
            pageder = content (path + "/" + key);
          in
          {
            input = pageder;
            output = "$out/${key + pageder.postname}";
          }
        else if (pkgs.lib.isDerivation content) then
          {
            input = content;
            output = "$out/${key + content.postname}";
          }
        else if (builtins.isPath content) then
          {
            input = content;
            output = "$out/${key}";
          }
        else
          {
            input = (buildSectionFromStructure content (path + "/" + key));
            output = "$out/${key}";
          };
      in if (key == "") then
          "cp -r ${info.input}/* $out/"
        else
          "ln -s ${info.input} ${info.output}"
        ))

        structure;

      instructions = pkgs.lib.concatStringsSep "\n" instructionsList;
    in
      pkgs.stdenv.mkDerivation {
        name = "site-a-structure";

        phases = "installPhase";

        installPhase = ''
          set -x
          mkdir -p $out
          ${instructions}
          set +x
        '';
      };


  structure = import ./structure.nix { inherit buildPage; buildArticlePage = blog.buildArticlePage; buildBlog = blog.buildBlog; };
in
  buildSectionFromStructure structure ""
