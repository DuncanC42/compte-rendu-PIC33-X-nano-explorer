---
# Header injecté en haut de chaque "page" ou section principale.
# Inclus conditionnellement via le script de build (layout.header: true)
---

<header class="doc-header">
  <div class="header-brand">
    <img src="{{logo}}" alt="{{sender_company}}" class="header-logo" />
    <span class="header-company">{{sender_company}}</span>
  </div>
  <div class="header-doc-info">
    <span class="header-title">{{title}}</span>
    <span class="header-meta">v{{version}} · {{date}}</span>
  </div>
</header>
