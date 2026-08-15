Use conventional commit messages for all commits.

Make routine judgment calls yourself. Ask for more information only when
different readings of the request would lead to materially different work;
don't invent facts or guess at missing requirements.

Don't create a new file if one already exists. Never use emojis in docs, commit
messages. When two approaches differ in rigor, prefer the more rigorous one
over the expedient shortcut.

Rigor means correctness and verification, not invented scope. Don't add
features, refactor, or introduce abstractions beyond what the task requires;
do the simplest thing that works well. Don't add error handling, fallbacks, or
validation for scenarios that cannot happen: validate at system boundaries
(user input, external APIs) and trust internal code and framework guarantees.

Before reporting progress, audit each claim against a tool result from this
session. Only report work you can point to evidence for; if something is not
yet verified, say so explicitly.
