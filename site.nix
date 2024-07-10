#TODO: translation

{ pkgs ? import <nixpkgs> {}}:

let
  footer = ./footer.html;
  header = ./header.html;

  # with the title, the body and the path of the page, return a derivation containing the page
  buildPage = title: body: path: pkgs.stdenv.mkDerivation {
    name = "site-page";

    phases = "installPhase";

    installPhase = ''
      cp ${header} $out
      substituteInPlace $out \
        --replace "{{title}}" "${title}"
      cat ${body} >> $out
      cat ${footer} >> $out
      substituteInPlace $out \
        --replace "<img src=\"./" "<img src=\"${path}/"
    '';
    
    postname = ".html";
  };

  buildBlogPage = blogTitle: folder: path: rec {
    data = builtins.fromTOML (builtins.readFile (builtins.toPath (folder + "/meta.toml")));

    date = data.date or "1970-01-01";

    page = pkgs.stdenv.mkDerivation {
      name = "site-blog-page";

      phases = "installPhase";

      installPhase = ''
        mkdir -p $out
        ln -s ${folder}/* $out
        rm $out/body.html
        rm $out/meta.toml
        cp ${buildPage data.title "${folder}/body.html" path} $out/index.html
      '';
      # It’s here that a good layout lack is evident
    };
  };

  buildBlogIndex = blogTitle: blogPosts: path:
    let
      instructionsList = pkgs.lib.mapAttrsToList
      (key: content: ''
        echo "<li><a href=\"${path}/${key}\">${content.date}: ${content.data.title}</a></li>" >> $out
      '') blogPosts;

      instructions = pkgs.lib.concatStringsSep "\n" instructionsList;
    in
    pkgs.stdenv.mkDerivation {
      name = "site-blog-index";

      phases = "installPhase";

      installPhase = ''
        cp ${header} $out
        substituteInPlace $out \
          --replace "{{title}}" "${blogTitle}"
        echo "<ul>" >> $out
        ${instructions}
        echo "</ul>" >> $out
        cat ${footer} >> $out
      '';
    };

  buildBlog = title: folder: path: let
    subfolder = builtins.readDir folder;

    #Don't know why I need to first compute ("/" + something). Probably a type thing, where folder isn't a string.
    data = pkgs.lib.mapAttrs (key: type: buildBlogPage title (folder + ("/" +  key)) (path + "/" + key)) subfolder;

    instructionsList = pkgs.lib.mapAttrsToList
      (key: content: "ln -s ${content.page} $out/${key}") data;
    
    instructions = pkgs.lib.concatStringsSep "\n" instructionsList;
  in
    pkgs.stdenv.mkDerivation {
      name = "site-blog";

      phases = "installPhase";

      installPhase = ''
        mkdir $out

        ${instructions}

        ln -s ${buildBlogIndex title data path} $out/index.html
      '';

      postname = "";
    };

  #path should not end with a slash
  buildSectionFromStructure = structure: path: 
    let
      instructionsList = (pkgs.lib.mapAttrsToList
        (key: content: if (pkgs.lib.isFunction content) then
          let
            pageder = content (path + "/" + key);
            subpath = key + pageder.postname;
          in
            "ln -s ${pageder} $out/${subpath}"
        else if (pkgs.lib.isDerivation content) then
          "ln -s ${content} $out/${key + content.postname}"
        else if (builtins.isPath content) then
          "ln -s ${content} $out/${key}"
        else
          "ln -s ${(buildSectionFromStructure content (path + "/" + key))} $out/${key}"
        ))
        
        structure;
      
      instructions = pkgs.lib.concatStringsSep "\n" instructionsList;
    in
      pkgs.stdenv.mkDerivation {
        name = "site-a-structure";
        
        phases = "installPhase";

        installPhase = ''
          mkdir -p $out
          ${instructions}
        '';
      };
      

  structure = import ./structure.nix { inherit buildPage buildBlog; };
in
  buildSectionFromStructure structure ""