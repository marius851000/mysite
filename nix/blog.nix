{ pkgs, util, generic_pagegen, ... }:

with pkgs.lib.strings;

rec {
  buildArticlePage = generic_pagegen.buildGenericPage wrapArticle;

  wrapArticle = extra_meta: body: path: let
    lang = extra_meta.lang;

    post_title_stuff = (util.createCreativeWorkShortMeta extra_meta) +
      (if extra_meta.type == "userReview" then (util.formatWorkFromData extra_meta "reviewed" lang "itemReviewed") else "");

    basic_content = util.getSchemaType extra_meta;
  in pkgs.stdenvNoCC.mkDerivation {
    name = "wrapped-article";

    phases = "installPhase";

    installPhase = ''
      cp ${../article_header.html} ./header.html
      cp ${../article_footer.html} ./footer.html

      for file in header.html footer.html; do
        substituteInPlace $file \
          --replace-quiet {{page_url}} ${escapeShellArg (util.urlFromPath path)} \
          --replace-quiet {{title}} ${escapeShellArg extra_meta.titleFormatted or extra_meta.title} \
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
      sortedBlogPosts = pkgs.lib.reverseList (pkgs.lib.sortOn (b: b.datePublished) (pkgs.lib.mapAttrsToList (key: content: content) blogPosts));

      # NOTE: a blogPost should only be of type BlogPosting. But not all the entry in my blog are. So I deliberately not follow this rule. Should I suggest an evolution in the schema for it to point to CreativeWork instead?
      instructionsList = pkgs.lib.map
      (content: ''
        echo "<li>
          <span itemscope itemprop=\"blogPost\" itemtype=\"${content.schemaType.itemtype}\" itemid=\"${util.urlFromPath (path + "/" + content.key)}\">
            <a href=\"/${content.path}\" itemprop=\"url\">${content.datePublished} ${content.lang}: <span itemprop=\"headline\">${content.data.titleFormatted or content.data.title}</span></a>
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

      extra_meta = {
        title = blogTitle;
      };
    in
      util.buildJustHtmlPage extra_meta (generic_pagegen.buildPage extra_meta body path null) path;

  buildBlog = title: folder: path: let
    subfolder = builtins.readDir folder;

    articles = pkgs.lib.mapAttrs (key: type: buildArticlePage
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
      (key: content: "ln -s ${content} $out/${key}") articles;

    instructions = pkgs.lib.concatStringsSep "\n" instructionsList;
  in
    pkgs.stdenv.mkDerivation {
      name = "site-blog";

      phases = "installPhase";

      passthru = {
        inherit articles path;
      };

      installPhase = ''
        mkdir $out

        ${instructions}
      '';

      postname = "";
    };
}
