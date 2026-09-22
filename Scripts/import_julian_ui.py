#!/usr/bin/env python3
"""Copy the pinned Agent navigation UI and record provenance; never edits the source checkout."""
import hashlib
import json
from pathlib import Path

SOURCE = Path('/tmp/julian-agent-vision-review.uBJpeD/areas/clients/shop/packages/shop-native-swiftui')
OUTPUT = Path(__file__).resolve().parents[1] / 'Vendor/JulianAgentUI'
manifest_path = OUTPUT / 'source-manifest.json'
manifest = json.loads(manifest_path.read_text())

def extract(relative, start, end, name, imports='import SwiftUI\nimport Gravity\nimport UIKit\n'):
    path = SOURCE / 'Shop/Sources' / relative
    raw = path.read_text()
    text = raw[raw.index(start):raw.index(end, raw.index(start))] if end else raw[raw.index(start):]
    target = OUTPUT / 'Sources/JulianAgentUI/Upstream' / name
    target.write_text(imports + '\n' + text)
    manifest['files'] = [f for f in manifest['files'] if f['destination'] != str(target.relative_to(OUTPUT))]
    manifest['files'].append({'source': 'Shop/Sources/' + relative, 'destination': str(target.relative_to(OUTPUT)),
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'extraction': {'start': start, 'end': end},
        'adaptations': ['Extracted complete UI/type declarations from a production integration file; no visual or motion changes.']})

extract('AppShell/ShopTabBarChrome.swift', 'enum ShopTabBarMetrics {', 'struct ShopTabBarChrome:', 'ShopTabBarMetrics.swift')
extract('AppShell/ShopTabRouter.swift', 'enum ShopRootTab:', '/// Canonical root-route mapping', 'ShopRootTab.swift')
extract('AppShell/ShopHomeView.swift', 'enum ShopHomeSearchLayout:', '/// The single set', 'ShopHomeSearchLayout.swift')
extract('AppShell/ShopTabShellView.swift', 'private struct ShopNavigationStylePickerSheet:', '#if DEBUG\nprivate struct ShopLoupeTools', 'ShopPrototypeSettings.swift')
# Settings are module-internal so the standalone shell can present the same sheet.
p = OUTPUT / 'Sources/JulianAgentUI/Upstream/ShopPrototypeSettings.swift'
p.write_text(p.read_text().replace('private struct ', 'struct '))
manifest['files'][-1]['adaptations'].append('Changed file-private settings structs to module-internal visibility.')
extract('Features/Agent/AgentIndex/ShopAgentIndexModels.swift', 'enum ShopAgentMessageContextItemType:', 'struct ShopAgentHint:', 'ShopAgentMessageContextItemType.swift')
extract('Features/Agent/AgentIndex/ShopAgentIndexModels.swift', 'struct ShopAgentMessageContextItem:', 'struct ShopAgentQueryClassificationBreakdown:', 'ShopAgentMessageContextItem.swift')
extract('Features/Agent/Attachments/ShopAgentImageAttachmentModels.swift', '/// Web parity', None, 'ShopAgentImageAttachmentModels.swift')
extract('Features/Agent/Attachments/ShopAgentImageAttachmentPreview.swift', 'enum ShopAgentImageAttachmentPreviewMetrics', 'struct ShopAgentImageAttachmentPreviewRow', 'ShopAgentImageAttachmentPreviewMetrics.swift')
extract('Features/Agent/Attachments/ShopAgentImageAttachmentPicker.swift', 'enum ShopAgentComposerAttachmentPickerSource:', 'enum ShopAgentImageAttachmentPermissionAlert:', 'ShopAgentComposerAttachmentPickerSource.swift')
extract('AppShell/ShopFloatingCartControl.swift', 'enum ShopFloatingCartButtonMode:', 'func shopFloatingCartHasSavedForLaterItems', 'ShopFloatingCartButtonMode.swift')
extract('Features/Agent/ShopAgentLandingModels.swift', 'enum ShopAgentLandingContextItemType:', '@MainActor\n@Observable\nfinal class ShopAgentLandingFocusRequests', 'ShopAgentLandingContextItem.swift')
extract('Features/Agent/AgentIndex/ShopAgentRouteContext.swift', 'func shopAgentMessageContextSummary(', None, 'ShopAgentMessageContextSummary.swift')
extract('AppShell/ShopTabShellView.swift', 'enum ShopCartPresentationOwner:', '/// Routes cart actions', 'ShopCartPresentationOwner.swift')
extract('Features/Search/Components/ShopSearchToolbar.swift', '/// A retained conversation', '/// One persistent search field', 'ShopSearchToolbarReturnContext.swift')
extract('Features/Search/Components/ShopSearchToolbar.swift', 'private struct ShopSearchToolbarControls', 'private struct ShopSearchToolbarAccountButton', 'ShopSearchToolbarControls.swift')
p = OUTPUT / 'Sources/JulianAgentUI/Upstream/ShopSearchToolbarControls.swift'
p.write_text(p.read_text().replace('private struct ', 'struct '))
manifest['files'][-1]['adaptations'].append('Module-internal visibility for standalone header host.')
extract('Features/Feed/Header/ShopFeedQuickLinksBar.swift', 'private struct ShopFeedSearchQuickLinkPill:', 'struct ShopFeedTrackedQuickLinkPill:', 'ShopFeedSearchControls.swift')
extract('Features/Feed/Header/ShopFeedHeaderBackdrop.swift', 'enum ShopFeedHeaderMetrics', 'struct ShopFeedHeaderBackdrop:', 'ShopFeedHeaderMetrics.swift')
extract('Features/Feed/Header/ShopFeedQuickLinksBar.swift', 'private struct ShopFeedQuickLinkPressButtonStyle:', 'private struct ShopFeedQuickLinkBackgroundImage:', 'ShopFeedQuickLinkPressButtonStyle.swift')
p = OUTPUT / 'Sources/JulianAgentUI/Upstream/ShopFeedQuickLinkPressButtonStyle.swift'
p.write_text(p.read_text().replace('private struct ', 'struct '))
extract('Features/Agent/ShopAgentLandingDockSource.swift', '/// Adapts the existing landing', '/// Toolbar preferences', 'ShopAgentLandingDockSource.swift')
p = OUTPUT / 'Sources/JulianAgentUI/Upstream/ShopFeedSearchControls.swift'
p.write_text(p.read_text().replace('import SwiftUI', 'import CoreImage.CIFilterBuiltins\nimport SwiftUI').replace('private struct ShopFeedSearchQuickLinkPill', 'struct ShopFeedSearchQuickLinkPill'))
extract('Features/Agent/ShopAgentComposerBar.swift', 'enum ShopAgentComposerMotion', 'struct ShopAgentComposerBar:', 'ShopAgentComposerInput.swift')
manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
print(f"Recorded {len(manifest['files'])} source files at {manifest['commit']}")
