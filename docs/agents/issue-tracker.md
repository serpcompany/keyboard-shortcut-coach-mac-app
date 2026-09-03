# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues. Use the `gh` CLI for all operations and infer the repository from `git remote -v`.

## Conventions

- Create: `gh issue create --title "..." --body-file <file>`.
- Read: `gh issue view <number> --comments` and fetch labels.
- List: `gh issue list --state open --json number,title,body,labels,comments` with suitable filters.
- Comment: `gh issue comment <number> --body "..."`.
- Label: `gh issue edit <number> --add-label "..."` or `--remove-label "..."`.
- Assign: `gh issue edit <number> --add-assignee @me`.
- Start work: create a linked branch with `gh issue develop <number> --base main --name <branch>`, assign the issue, and replace its triage label with `in-progress`.
- Open a draft pull request as soon as the branch has a coherent first commit.
- Close: `gh issue close <number> --comment "..."`.

Pull requests are not a request surface.
