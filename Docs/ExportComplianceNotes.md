# TimeNest Export Compliance Notes

> Submission-preparation notes only. They do not determine the final App Store Connect answer and are not legal advice. Answer Apple's current export-compliance questions manually for the exact submitted build.

## Current Technical Inventory

- TimeNest uses standard HTTPS networking to access public ICS holiday providers selected by the user.
- The app may include and use the Google Mobile Ads SDK in the submitted build, depending on the final production advertising configuration.
- The current TimeNest source does not implement custom or proprietary encryption algorithms or cryptographic features.
- The current app has no account system, developer-operated cloud synchronization, TimeNest-owned backend upload, or private encrypted communication protocol.
- Local App Group sharing between TimeNest and its Widget is on-device file sharing, not a private network protocol.

## Submission Notes

- **TODO:** Confirm the exact frameworks and SDKs embedded in the final archive.
- **TODO:** Read and answer the then-current App Store Connect export-compliance questionnaire based on the submitted binary and intended distribution regions.
- **TODO:** Determine with the appropriate legal/compliance owner whether the app's use of operating-system HTTPS and third-party SDK encryption qualifies for an exemption and whether documentation is required.
- **TODO:** Keep the App Store Connect answer consistent with any export-compliance documentation requested for the build.

Do not add or modify `ITSAppUsesNonExemptEncryption` as part of this documentation task. Any future InfoPlist decision must be made separately after the final manual compliance review.
