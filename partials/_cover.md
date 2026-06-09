---
# Ce fichier est inclus EN PREMIER dans l'assemblage final.
# Les variables {{...}} sont remplacées par le script de build depuis project.yaml
---

<div class="cover-page">

<div class="cover-logo">
  <img src="{{logo}}" alt="{{sender_company}}" />
</div>

<div class="cover-content">
  <div class="cover-doc-type">{{doc_type | upper}}</div>
  <h1 class="cover-title">{{title}}</h1>
  <p class="cover-subtitle">{{subtitle}}</p>
</div>

<div class="cover-meta">
  <div class="cover-meta-block">
    <span class="cover-label">Préparé par</span>
    <span class="cover-value">{{author}}</span>
    <span class="cover-value muted">{{sender_company}}</span>
  </div>
  <div class="cover-meta-block">
    <span class="cover-label">Destinataire</span>
    <span class="cover-value">{{recipient_name}}</span>
    <span class="cover-value muted">{{recipient_company}}</span>
  </div>
  <div class="cover-meta-block">
    <span class="cover-label">Date</span>
    <span class="cover-value">{{date}}</span>
  </div>
  <div class="cover-meta-block">
    <span class="cover-label">Version</span>
    <span class="cover-value">{{version}}</span>
  </div>
</div>

</div>
