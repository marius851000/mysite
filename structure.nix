{ buildArticlePage, buildBlog, buildBlogIndex, buildStaticFile, ... }:

let
  personalBlog = buildBlog "Blog de marius" ./blog "blog";

  reviewBlog = buildBlog "Critiques de marius" ./review "review";

  articles = personalBlog.articles // reviewBlog.articles;

  blogMainPage = buildBlogIndex "Blog de marius" articles "blog";
in [
  (buildArticlePage {} ./pages/index "" null)
  (buildStaticFile ./style.css "style.css")

  blogMainPage
  personalBlog
  reviewBlog
]
