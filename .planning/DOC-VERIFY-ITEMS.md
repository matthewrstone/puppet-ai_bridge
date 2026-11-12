# Open documentation verification items

Moved out of the published docs on 2026-11-11 (they were hidden HTML comments). Each is a claim about PE
internals that could not be confirmed from this repository; confirm against a real PE before stating it as fact.

- `docs/ARCHITECTURE.md`: which truststore the PE console/AI Agent JVM uses for outbound HTTPS, and that it includes the Puppet CA by default; this cannot be confirmed from the repository
- `docs/ARCHITECTURE.md`: that PE's JVM falls back to the default Java cacerts for outbound connections
- `docs/CONFIGURATION.md`: exact output paths of `puppetserver ca generate` depend on the PE version and ssldir setting
- `docs/CONFIGURATION.md`: the PE console JVM truststore includes the public root used by your chosen CA
- `docs/GETTING-STARTED.md`: exact output paths of `puppetserver ca generate` depend on the PE version and ssldir setting; not confirmable from this repository
- `docs/GETTING-STARTED.md`: which truststore the PE console JVM uses to validate the bridge certificate, and that it trusts the Puppet CA by default, is PE internals and cannot be confirmed from this repository
- `docs/USER_GUIDE.md`: exact output paths of `puppetserver ca generate` depend on the PE version and ssldir; and confirm which truststore PE's console/AI Agent JVM uses for outbound HTTPS and that it includes the Puppet CA. Previously this guide stated the console "definitely trusts" the Puppet CA, which cannot be confirmed from this repository.
