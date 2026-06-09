---
# Footer injecté en bas du document final.
# Inclus conditionnellement via le script de build (layout.footer: true)
---

<footer class="doc-footer">
  <div class="footer-left">
    <span>{{sender_company}}</span>
    <a href="{{sender_website}}">{{sender_website}}</a>
  </div>
  <div class="footer-center">
    {{#if footer.custom_text}}
      <span>{{footer.custom_text}}</span>
    {{else}}
      <span>Confidentiel — Document préparé pour {{recipient_company}}</span>
    {{/if}}
  </div>
  <div class="footer-right">
    <span>{{date}}</span>
    <span class="footer-page">Page <span class="page-number"></span></span>
  </div>
</footer>
