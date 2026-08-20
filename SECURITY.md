# Security policy

MacGlow is pre-alpha and does not yet publish stable releases.

Please report vulnerabilities privately to the project maintainers rather than
opening a public issue. Until a dedicated security address is configured, use
the repository owner's private contact channel.

MacGlow's security boundary is intentionally narrow: raw audio stays in memory
only long enough to calculate local features, and the default build contains no
analytics or network client. Changes that expand this boundary require explicit
documentation and review.
