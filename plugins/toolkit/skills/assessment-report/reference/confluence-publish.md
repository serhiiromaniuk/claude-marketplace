# Publishing to Confluence (+ attaching the PDF)

Publishing is **outward-facing** — confirm with the user before creating/updating anything. Use the Atlassian Rovo MCP for the page; the PDF attachment currently needs a manual step (see gotcha).

## 1. Resolve IDs
```
getConfluencePage(cloudId="<site>.atlassian.net", pageId=<parent>)   # confirm parent + space key
getConfluenceSpaces(cloudId=..., keys="<SPACEKEY>")                   # -> numeric spaceId (needed to create)
```

## 2. Create the page
```
createConfluencePage(cloudId, spaceId=<numeric>, parentId=<parent>,
  title="...", contentFormat="html", body="<html-ish storage>")
```
- **Title is plain text** — pass a literal `&`, NOT `&amp;` (it renders as the literal word "amp" otherwise).
- Body uses Confluence-flavored HTML: `<div data-type="panel-info|note|warning">`, `<span data-type="status" data-color="red|yellow|green">…</span>`, tables, headings. Keep it a **summary** — link/attach the full PDF rather than pasting the whole report.
- A good summary: info panel + verdict status lozenge + key numbers + an at-a-glance table + "fix first" list + a scope/method note.

## 3. Attach the PDF — GOTCHA
- The **Rovo MCP has no attachment-upload tool** (page CRUD only).
- The **browser `file_upload`** tool may reject host filesystem paths in some runtimes ("no longer accepts host filesystem paths" / "files must be shared with this session"). When it works, the reliable target is the legacy attachments page:
  `https://<site>/wiki/pages/viewpageattachments.action?pageId=<id>` → `find` the file input → `file_upload` → it has an "Upload file" control.
- **Fallback (reliable):** create the page, then ask the user to drag-drop the PDF onto the page, or click *Upload file* on the attachments page (open it for them). Word the summary as "full report attached below" so it reads correctly once uploaded.
- If the user supplies a Confluence **API token** themselves, the REST attachment endpoint is `POST /wiki/rest/api/content/{id}/child/attachment` with `-F file=@report.pdf -H "X-Atlassian-Token: nocheck"`. Do not handle/enter their credentials yourself — that's theirs to run.

## 4. Verify
Return the page URL (`_links.webui`) and confirm the title rendered correctly.
