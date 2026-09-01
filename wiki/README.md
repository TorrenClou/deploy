# Wiki source

These files are the GitHub wiki for this repository. The wiki lives in a separate git
repository, so they are edited here and pushed there.

To publish:

```bash
git clone https://github.com/TorrenClou/deploy.wiki.git /tmp/deploy-wiki
cp wiki/*.md /tmp/deploy-wiki/
cd /tmp/deploy-wiki
rm -f README.md            # the wiki has no use for this file
git add -A && git commit -m "docs: update wiki" && git push
```

The filename becomes the page name, with hyphens rendered as spaces. `Home.md` is the
landing page.

Keep the README in this repository short. Anything longer than a paragraph belongs here.
