Deploy the backend to Render by pushing to master.

Render auto-deploys on every push to master (M1thieu/greengains). Steps:
1. Run `git status` to confirm working tree is clean
2. Run `git push origin master`
3. Confirm the push succeeded and remind the user that Render will deploy automatically (typically takes 2-3 minutes)

Do NOT push if there are uncommitted changes — ask the user to commit first.
