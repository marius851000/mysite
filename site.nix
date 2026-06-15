#TODO: translation

{ pkgs ? import <nixpkgs> {}}:

with pkgs.lib.strings;

let
  util = import ./util.nix { pkgs = pkgs; };

  siteroot = "https://mariusdavid.fr";

  urlFromPath = path: "${siteroot}${path}/";

  # with the title, the body and the path of the page, return a derivation containing the page
  # path is the path relative to the site root, folder is the folder containing the page, used for substitution. May be null.
  buildPage = extra_meta: body: path: folder: let
    wrapped_main = wrapMain extra_meta body path;
  in wrapped_main;

  wrapMain = extra_meta: body: path: let
    title = if extra_meta ? title then extra_meta.title else throw "article without title: ${path}";

    modified_date = if extra_meta ? "modified-date" then extra_meta."modified-date" else if extra_meta ? "date" then extra_meta."date" else null;

    extra_header = "<meta property=\"og:title\" content=\"${title}\" />" +
      (if extra_meta ? type then "\n<meta property=\"og:type\" content=\"${extra_meta.type}\" />" else "") +
      (if extra_meta ? date then "\n<meta property=\"article:published_time\" content=\"${extra_meta.date}T00:00:00+00:00\" />" else "") +
      (if modified_date != null then "\n<meta property=\"article:modified_time\" content=\"${modified_date}T00:00:00+00:00\" />" else "") +
      (if extra_meta ? lang then "\n<meta property=\"og:locale\" content=\"${extra_meta.lang}_FR\" />" else "") +
      (if extra_meta ? description then "\n<meta property=\"og:description\" content=\"${extra_meta.description}\" />" else "");

    lang = if extra_meta ? lang then extra_meta.lang else "fr";
  in pkgs.stdenvNoCC.mkDerivation {
    name = "header-html-wrapped";

    phases = "installPhase";

    nativeBuildInputs = [ pkgs.prettier ];

    installPhase = ''
      cp ${./header.html} result.html
      substituteInPlace result.html \
        --replace-quiet {{extra_header}} ${escapeShellArg extra_header} \
        --replace-quiet {{lang}} ${escapeShellArg lang} \
        --replace-quiet {{title}} ${escapeShellArg title}

      cat ${body} >> result.html

      cat ${./footer.html} >> result.html

      substituteInPlace result.html \
        --replace-quiet "<img src=\"./" "<img src=\"${path}/"

      prettier --parser html result.html > $out
    '';

    postname = ".html";
  };

  wrapArticle = extra_meta: body: path: let
    lang = extra_meta.lang;

    publication_date_span = "<span itemprop=\"datePublished\" content=\"${extra_meta."date"}\">";
    publication_date_text = if (extra_meta ? "date") then (
      if lang == "en" then (
        "Published on ${publication_date_span}${util.formatDateEnglish extra_meta.date}</span>"
      ) else if lang == "fr" then (
        "Publié le ${publication_date_span}${util.formatDateFrench extra_meta.date}</span>"
      ) else throw "publication date: unknown language ${lang}"
    ) else null;

    modification_date_span = "<span itemprop=\"dateModified\" content=\"${extra_meta."date"}\">";
    modification_date_text = if (extra_meta ? "modified-date") then (
      if lang == "en" then (
        "Last changed on ${modification_date_span}${util.formatDateEnglish extra_meta."modified-date"}</span>"
      ) else if lang == "fr" then (
        "Modifié le ${modification_date_span}${util.formatDateFrench extra_meta."modified-date"}</span>"
      ) else throw "modification date: unknown language ${lang}"
    ) else null;

    post_title_stuff = (if (extra_meta ? "description" && !(extra_meta ? "displayDescription" && extra_meta.displayDescription == false)) then (
        "<p itemprop=\"headline\" class=\"article-headline\">${extra_meta.description}</p>\n"
      ) else "") +
      (if (publication_date_text != null && modification_date_text != null) then (
        "<p class=\"article-meta\"><i>${publication_date_text} (${modification_date_text})</i></p>\n"
      ) else if (publication_date_text != null) then (
        "<p class=\"article-meta\"><i>${publication_date_text}</i></p>\n"
      ) else if (modification_date_text != null) then (
        "<p class=\"article-meta\"><i>${modification_date_text}</i></p>\n"
      ) else "");

      basic_content = if extra_meta.type == "blogPost" then {
        "itemtype" = "https://schema.org/BlogPosting";
        "bodyprop" = "articleBody";
      } else if (extra_meta.type == "webPage" || extra_meta.type == "aboutPage") then {
        "itemtype" = if extra_meta.type == "aboutPage" then "https://schema.org/AboutPage" else "https://schema.org/WebPage";
        "bodyprop" = "mainContentOfPage";
      } else throw "unknown type: ${extra_meta.type}";
  in pkgs.stdenvNoCC.mkDerivation {
    name = "wrapped-article";

    phases = "installPhase";

    installPhase = ''
      cp ${./article_header.html} ./header.html
      cp ${./article_footer.html} ./footer.html

      for file in header.html footer.html; do
        substituteInPlace $file \
          --replace-quiet {{page_url}} ${escapeShellArg (urlFromPath path)} \
          --replace-quiet {{title}} ${escapeShellArg extra_meta.title} \
          --replace-quiet {{post_title_stuff}} ${escapeShellArg post_title_stuff} \
          --replace-quiet {{itemtype}} ${escapeShellArg basic_content.itemtype} \
          --replace-quiet {{bodyprop}} ${escapeShellArg basic_content.bodyprop}
      done

      cp ./header.html $out
      cat ${body} >> $out
      cat ./footer.html >> $out
    '';
  };

  patchBody = body: path: folder: let
    placeholder_file_path = folder + "/placeholder.nix";
    placeholder_exist = builtins.pathExists placeholder_file_path;
    placeholder_value = if (folder != null && placeholder_exist) then (
      import placeholder_file_path { inherit pkgs; }
    ) else [];
    placeholder_replace_command = builtins.concatStringsSep "\n" (builtins.map
      (x:
        ''substituteInPlace $out --replace-fail ${escapeShellArg ("{{" + x.holder + "}}")} ${escapeShellArg x.to}''
      )
      placeholder_value);
  in pkgs.stdenvNoCC.mkDerivation {
      name = "patched-body";

      phases = "installPhase";

      installPhase = ''
        cp ${body} $out
        ${placeholder_replace_command}
      '';
    };

  buildArticlePage = metadata: folder: path: key: let
    data = {
      type = "webPage";
    }
      // metadata
      // (builtins.fromTOML (builtins.readFile (builtins.toPath (folder + "/meta.toml"))));

    body_patched = patchBody "${folder}/body.html" path folder;
    wrapped_in_article = wrapArticle data body_patched path;
    wrapped_in_header = wrapMain data wrapped_in_article path;
  in {
    inherit key data;

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
        ln -s ${wrapped_in_header} $out/index.html
      '';

      postname = "";
    };
  };

  buildBlogIndex = blogTitle: blogPosts: path:
    let
      sortedBlogPosts = pkgs.lib.reverseList (pkgs.lib.sortOn (b: b.date) (pkgs.lib.mapAttrsToList (key: content: content) blogPosts));

      instructionsList = pkgs.lib.map
      (content: ''
        echo "<li>
          <span itemscope itemprop=\"blogPost\" itemtype=\"https://schema.org/BlogPosting\" itemid=\"${urlFromPath (path + "/" + content.key)}\">
            <a href=\"${path}/${content.key}\" itemprop=\"url\">${content.date} ${content.lang}: <span itemprop=\"headline\">${content.data.title}</span></a>
          </span>
        </li>" >> $out
      '') sortedBlogPosts;

      instructions = pkgs.lib.concatStringsSep "\n" instructionsList;

      body = pkgs.stdenvNoCC.mkDerivation {
        name = "site-blog-index-body";

        phases = "installPhase";

        installPhase = ''
          echo "<div itemscope itemtype=\"https://schema.org/Blog\" itemid=\"${urlFromPath path}\">" >> $out
          echo "<h1 itemprop=\"name\">${blogTitle}</h1>" >> $out

          echo "<ul>" >> $out
          ${instructions}
          echo "</ul>" >> $out
          echo "</div>" >> $out
        '';
      };
    in
      buildPage {
        title = blogTitle;
      } body path null;

  buildBlog = title: folder: path: let
    subfolder = builtins.readDir folder;

    data = pkgs.lib.mapAttrs (key: type: buildArticlePage
      { type = "blogPost"; }
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


  structure = import ./structure.nix { inherit buildPage buildBlog buildArticlePage; };
in
  buildSectionFromStructure structure ""
