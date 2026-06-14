#TODO: translation

{ pkgs ? import <nixpkgs> {}}:

with pkgs.lib.strings;

let
  footer = ./footer.html;
  header = ./header.html;

  # with the title, the body and the path of the page, return a derivation containing the page
  # path is the path relative to the site root, folder is the folder containing the page, used for substitution. May be null.
  buildPage = extra_meta: body: path: folder: let
    title = if extra_meta ? title then extra_meta.title else throw "article without title: ${path}";

    placeholder_file_path = folder + "/placeholder.nix";
    placeholder_exist = builtins.pathExists placeholder_file_path;
    placeholder_value = if (folder != null && placeholder_exist) then (
      import placeholder_file_path { inherit pkgs; }
    ) else [];
    placeholder_replace_command = builtins.concatStringsSep "\n" (builtins.map
      (x:
        ''substituteInPlace body.html --replace-fail ${escapeShellArg ("{{" + x.holder + "}}")} ${escapeShellArg x.to}''
      )
      placeholder_value);

    modified_date = if extra_meta ? "modified-date" then extra_meta."modified-date" else if extra_meta ? "date" then extra_meta."date" else null;

    extra_header = "<meta property=\"og:title\" content=\"${title}\" />" +
      (if extra_meta ? type then "\n<meta property=\"og:type\" content=\"${extra_meta.type}\" />" else "") +
      (if extra_meta ? date then "\n<meta property=\"article:published_time\" content=\"${extra_meta.date}T00:00:00+00:00\" />" else "") +
      (if modified_date != null then "\n<meta property=\"article:modified_time\" content=\"${modified_date}T00:00:00+00:00\" />" else "") +
      (if extra_meta ? lang then "\n<meta property=\"og:locale\" content=\"${extra_meta.lang}_FR\" />" else "") +
      (if extra_meta ? description then "\n<meta property=\"og:description\" content=\"${extra_meta.description}\" />" else "");

    lang = if extra_meta ? lang then extra_meta.lang else "fr";
  in pkgs.stdenv.mkDerivation {
    name = "site-page";

    phases = "installPhase";

    installPhase = ''
      echo managing ${escapeShellArg title}
      cp ${header} $out
      substituteInPlace $out \
        --replace-quiet {{title}} ${escapeShellArg title} \
        --replace-quiet {{extra_header}} ${escapeShellArg extra_header} \
        --replace-quiet {{lang}} ${escapeShellArg lang}
      cp ${body} body.html
      echo "running placeholder substitution"
      ${placeholder_replace_command}
      echo "doing the rest"
      cat body.html >> $out
      cat ${footer} >> $out
      substituteInPlace $out \
        --replace-quiet "<img src=\"./" "<img src=\"${path}/"
    '';

    postname = ".html";
  };

  buildBlogPage = blogTitle: folder: path: key: rec {
    inherit key;

    data = {
      type = "article";
    } // builtins.fromTOML (builtins.readFile (builtins.toPath (folder + "/meta.toml")));

    date = data.date or "1970-01-01";
    lang = data.lang;

    page = pkgs.stdenv.mkDerivation {
      name = "site-blog-page";

      phases = "installPhase";

      installPhase = ''
        mkdir -p $out
        ln -s ${folder}/* $out
        rm -f $out/body.html
        rm -f $out/meta.toml
        rm -f $out/index.html
        ln -s ${buildPage data "${folder}/body.html" path folder} $out/index.html
      '';
      # It’s here that a good layout lack is evident
    };
  };

  buildBlogIndex = blogTitle: blogPosts: path:
    let
      sortedBlogPosts = pkgs.lib.reverseList (pkgs.lib.sortOn (b: b.date) (pkgs.lib.mapAttrsToList (key: content: content) blogPosts));

      instructionsList = pkgs.lib.map
      (content: ''
        echo "<li><a href=\"${path}/${content.key}\">${content.date} ${content.lang}: ${content.data.title}</a></li>" >> $out
      '') sortedBlogPosts;

      instructions = pkgs.lib.concatStringsSep "\n" instructionsList;

      body = pkgs.stdenvNoCC.mkDerivation {
        name = "site-blog-index-body";

        phases = "installPhase";

        installPhase = ''
          echo "<ul>" > $out
          ${instructions}
          echo "</ul>" >> $out
        '';
      };
    in
      buildPage {
        title = blogTitle;
      } body path null;

  buildBlog = title: folder: path: let
    subfolder = builtins.readDir folder;

    data = pkgs.lib.mapAttrs (key: type: buildBlogPage
      title
      (builtins.path {
        path = folder + ("/" + key);
        # avoid problem with name containing invalid characters
        name = "blog-entry-source";
      })
      (path + ("/" +  key))
      key
    ) subfolder;

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
