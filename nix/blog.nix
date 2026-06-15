{ pkgs, util, generic_pagegen, ... }:

with pkgs.lib.strings;

rec {
  buildArticlePage = generic_pagegen.buildGenericPage wrapArticle;

  wrapArticle = extra_meta: body: path: let
    lang = extra_meta.lang;

    publication_date_span = "<span itemprop=\"datePublished\" content=\"${util.dateToDefaultISO8601 extra_meta."date"}\">";
    publication_date_text = if (extra_meta ? "date") then (
      if lang == "en" then (
        "Published on ${publication_date_span}${util.formatDateEnglish extra_meta.date}</span>"
      ) else if lang == "fr" then (
        "Publié le ${publication_date_span}${util.formatDateFrench extra_meta.date}</span>"
      ) else throw "publication date: unknown language ${lang}"
    ) else null;

    modification_date_span = "<span itemprop=\"dateModified\" content=\"${util.dateToDefaultISO8601 extra_meta."date"}\">";
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
      cp ${../article_header.html} ./header.html
      cp ${../article_footer.html} ./footer.html

      for file in header.html footer.html; do
        substituteInPlace $file \
          --replace-quiet {{page_url}} ${escapeShellArg (util.urlFromPath path)} \
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

  buildBlogIndex = blogTitle: blogPosts: path:
    let
      sortedBlogPosts = pkgs.lib.reverseList (pkgs.lib.sortOn (b: b.date) (pkgs.lib.mapAttrsToList (key: content: content) blogPosts));

      instructionsList = pkgs.lib.map
      (content: ''
        echo "<li>
          <span itemscope itemprop=\"blogPost\" itemtype=\"https://schema.org/BlogPosting\" itemid=\"${util.urlFromPath (path + "/" + content.key)}\">
            <a href=\"${path}/${content.key}\" itemprop=\"url\">${content.date} ${content.lang}: <span itemprop=\"headline\">${content.data.title}</span></a>
          </span>
        </li>" >> $out
      '') sortedBlogPosts;

      instructions = pkgs.lib.concatStringsSep "\n" instructionsList;

      body = pkgs.stdenvNoCC.mkDerivation {
        name = "site-blog-index-body";

        phases = "installPhase";

        installPhase = ''
          echo "<div itemscope itemtype=\"https://schema.org/Blog\" itemid=\"${util.urlFromPath path}\">" >> $out
          echo "<h1 itemprop=\"name\">${blogTitle}</h1>" >> $out

          echo "<ul>" >> $out
          ${instructions}
          echo "</ul>" >> $out
          echo "</div>" >> $out
        '';
      };
    in
      generic_pagegen.buildPage {
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
}
