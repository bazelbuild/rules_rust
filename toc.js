// Populate the sidebar
//
// This is a script, and not included directly in the page, to control the total size of the book.
// The TOC contains an entry for each page, so if each page includes a copy of the TOC,
// the total size of the page becomes O(n**2).
class MDBookSidebarScrollbox extends HTMLElement {
    constructor() {
        super();
    }
    connectedCallback() {
        this.innerHTML = '<ol class="chapter"><li class="chapter-item expanded affix "><a href="index.html">Introduction</a></li><li class="chapter-item expanded affix "><li class="spacer"></li><li class="chapter-item expanded "><a href="rules.html"><strong aria-hidden="true">1.</strong> Rules</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="rust.html"><strong aria-hidden="true">1.1.</strong> rust</a></li><li class="chapter-item expanded "><a href="rust_clippy.html"><strong aria-hidden="true">1.2.</strong> clippy</a></li><li class="chapter-item expanded "><a href="rust_fmt.html"><strong aria-hidden="true">1.3.</strong> rustfmt</a></li><li class="chapter-item expanded "><a href="rust_doc.html"><strong aria-hidden="true">1.4.</strong> rustdoc</a></li><li class="chapter-item expanded "><a href="cargo.html"><strong aria-hidden="true">1.5.</strong> cargo</a></li><li class="chapter-item expanded "><a href="rust_analyzer.html"><strong aria-hidden="true">1.6.</strong> rust_analyzer</a></li><li class="chapter-item expanded "><a href="rust_unpretty.html"><strong aria-hidden="true">1.7.</strong> unpretty</a></li></ol></li><li class="chapter-item expanded "><a href="settings.html"><strong aria-hidden="true">2.</strong> Settings</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="rust_settings.html"><strong aria-hidden="true">2.1.</strong> Rust Settings</a></li><li class="chapter-item expanded "><a href="cargo_settings.html"><strong aria-hidden="true">2.2.</strong> Cargo Settings</a></li></ol></li><li class="chapter-item expanded "><a href="rust_toolchains.html"><strong aria-hidden="true">3.</strong> Toolchains</a></li><li class="chapter-item expanded "><a href="rust_bzlmod.html"><strong aria-hidden="true">4.</strong> Bzlmod</a></li><li class="chapter-item expanded "><a href="rust_repositories.html"><strong aria-hidden="true">5.</strong> Repositories</a></li><li class="chapter-item expanded "><a href="external_crates.html"><strong aria-hidden="true">6.</strong> External Crates</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="crate_universe_bzlmod.html"><strong aria-hidden="true">6.1.</strong> crate_universe (bzlmod)</a></li><li class="chapter-item expanded "><a href="crate_universe_workspace.html"><strong aria-hidden="true">6.2.</strong> crate_universe (WORKSPACE)</a></li></ol></li><li class="chapter-item expanded "><a href="upstream_tooling.html"><strong aria-hidden="true">7.</strong> Upstream Tooling</a></li><li class="chapter-item expanded "><a href="ide_integrations.html"><strong aria-hidden="true">8.</strong> IDE Integrations</a></li><li class="chapter-item expanded "><a href="extensions.html"><strong aria-hidden="true">9.</strong> Extensions</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="rust_bindgen.html"><strong aria-hidden="true">9.1.</strong> bindgen</a></li><li class="chapter-item expanded "><a href="rust_mdbook.html"><strong aria-hidden="true">9.2.</strong> mdbook</a></li><li class="chapter-item expanded "><a href="rust_prost.html"><strong aria-hidden="true">9.3.</strong> prost</a></li><li class="chapter-item expanded "><a href="rust_protobuf.html"><strong aria-hidden="true">9.4.</strong> protobuf</a></li><li class="chapter-item expanded "><a href="rust_pyo3.html"><strong aria-hidden="true">9.5.</strong> pyo3</a></li><li class="chapter-item expanded "><a href="rust_wasm_bindgen.html"><strong aria-hidden="true">9.6.</strong> wasm_bindgen</a></li></ol></li></ol>';
        // Set the current, active page, and reveal it if it's hidden
        let current_page = document.location.href.toString().split("#")[0];
        if (current_page.endsWith("/")) {
            current_page += "index.html";
        }
        var links = Array.prototype.slice.call(this.querySelectorAll("a"));
        var l = links.length;
        for (var i = 0; i < l; ++i) {
            var link = links[i];
            var href = link.getAttribute("href");
            if (href && !href.startsWith("#") && !/^(?:[a-z+]+:)?\/\//.test(href)) {
                link.href = path_to_root + href;
            }
            // The "index" page is supposed to alias the first chapter in the book.
            if (link.href === current_page || (i === 0 && path_to_root === "" && current_page.endsWith("/index.html"))) {
                link.classList.add("active");
                var parent = link.parentElement;
                if (parent && parent.classList.contains("chapter-item")) {
                    parent.classList.add("expanded");
                }
                while (parent) {
                    if (parent.tagName === "LI" && parent.previousElementSibling) {
                        if (parent.previousElementSibling.classList.contains("chapter-item")) {
                            parent.previousElementSibling.classList.add("expanded");
                        }
                    }
                    parent = parent.parentElement;
                }
            }
        }
        // Track and set sidebar scroll position
        this.addEventListener('click', function(e) {
            if (e.target.tagName === 'A') {
                sessionStorage.setItem('sidebar-scroll', this.scrollTop);
            }
        }, { passive: true });
        var sidebarScrollTop = sessionStorage.getItem('sidebar-scroll');
        sessionStorage.removeItem('sidebar-scroll');
        if (sidebarScrollTop) {
            // preserve sidebar scroll position when navigating via links within sidebar
            this.scrollTop = sidebarScrollTop;
        } else {
            // scroll sidebar to current active section when navigating via "next/previous chapter" buttons
            var activeSection = document.querySelector('#sidebar .active');
            if (activeSection) {
                activeSection.scrollIntoView({ block: 'center' });
            }
        }
        // Toggle buttons
        var sidebarAnchorToggles = document.querySelectorAll('#sidebar a.toggle');
        function toggleSection(ev) {
            ev.currentTarget.parentElement.classList.toggle('expanded');
        }
        Array.from(sidebarAnchorToggles).forEach(function (el) {
            el.addEventListener('click', toggleSection);
        });
    }
}
window.customElements.define("mdbook-sidebar-scrollbox", MDBookSidebarScrollbox);
