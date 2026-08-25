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
        this.innerHTML = '<ol class="chapter"><li class="chapter-item expanded affix "><a href="index.html">Introduction</a></li><li class="chapter-item expanded affix "><li class="spacer"></li><li class="chapter-item expanded "><a href="rules.html"><strong aria-hidden="true">1.</strong> Rules</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="rust.html"><strong aria-hidden="true">1.1.</strong> rust</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="rust_binary.html"><strong aria-hidden="true">1.1.1.</strong> rust_binary</a></li><li class="chapter-item expanded "><a href="rust_library.html"><strong aria-hidden="true">1.1.2.</strong> rust_library</a></li><li class="chapter-item expanded "><a href="rust_library_group.html"><strong aria-hidden="true">1.1.3.</strong> rust_library_group</a></li><li class="chapter-item expanded "><a href="rust_lint_config.html"><strong aria-hidden="true">1.1.4.</strong> rust_lint_config</a></li><li class="chapter-item expanded "><a href="rust_cdylib_library.html"><strong aria-hidden="true">1.1.5.</strong> rust_cdylib_library</a></li><li class="chapter-item expanded "><a href="rust_dylib_library.html"><strong aria-hidden="true">1.1.6.</strong> rust_dylib_library</a></li><li class="chapter-item expanded "><a href="rust_proc_macro.html"><strong aria-hidden="true">1.1.7.</strong> rust_proc_macro</a></li><li class="chapter-item expanded "><a href="rust_shared_library.html"><strong aria-hidden="true">1.1.8.</strong> rust_shared_library</a></li><li class="chapter-item expanded "><a href="rust_static_library.html"><strong aria-hidden="true">1.1.9.</strong> rust_static_library</a></li><li class="chapter-item expanded "><a href="rust_test.html"><strong aria-hidden="true">1.1.10.</strong> rust_test</a></li><li class="chapter-item expanded "><a href="rust_test_suite.html"><strong aria-hidden="true">1.1.11.</strong> rust_test_suite</a></li></ol></li><li class="chapter-item expanded "><a href="clippy.html"><strong aria-hidden="true">1.2.</strong> clippy</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="rust_clippy.html"><strong aria-hidden="true">1.2.1.</strong> rust_clippy</a></li><li class="chapter-item expanded "><a href="rust_clippy_aspect.html"><strong aria-hidden="true">1.2.2.</strong> rust_clippy_aspect</a></li><li class="chapter-item expanded "><a href="rust_clippy_test.html"><strong aria-hidden="true">1.2.3.</strong> rust_clippy_test</a></li></ol></li><li class="chapter-item expanded "><a href="rustfmt.html"><strong aria-hidden="true">1.3.</strong> rustfmt</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="rustfmt_aspect.html"><strong aria-hidden="true">1.3.1.</strong> rustfmt_aspect</a></li><li class="chapter-item expanded "><a href="rustfmt_test.html"><strong aria-hidden="true">1.3.2.</strong> rustfmt_test</a></li></ol></li><li class="chapter-item expanded "><a href="rustdoc.html"><strong aria-hidden="true">1.4.</strong> rustdoc</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="rust_doc.html"><strong aria-hidden="true">1.4.1.</strong> rust_doc</a></li><li class="chapter-item expanded "><a href="rust_doc_test.html"><strong aria-hidden="true">1.4.2.</strong> rust_doc_test</a></li></ol></li><li class="chapter-item expanded "><a href="cargo.html"><strong aria-hidden="true">1.5.</strong> cargo</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="cargo_build_script.html"><strong aria-hidden="true">1.5.1.</strong> cargo_build_script</a></li><li class="chapter-item expanded "><a href="cargo_env.html"><strong aria-hidden="true">1.5.2.</strong> cargo_env</a></li><li class="chapter-item expanded "><a href="extract_cargo_lints.html"><strong aria-hidden="true">1.5.3.</strong> extract_cargo_lints</a></li></ol></li><li class="chapter-item expanded "><a href="rust_analyzer.html"><strong aria-hidden="true">1.6.</strong> rust_analyzer</a></li><li class="chapter-item expanded "><a href="unpretty.html"><strong aria-hidden="true">1.7.</strong> unpretty</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="rust_unpretty.html"><strong aria-hidden="true">1.7.1.</strong> rust_unpretty</a></li><li class="chapter-item expanded "><a href="rust_unpretty_aspect.html"><strong aria-hidden="true">1.7.2.</strong> rust_unpretty_aspect</a></li></ol></li></ol></li><li class="chapter-item expanded "><a href="settings.html"><strong aria-hidden="true">2.</strong> Settings</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="rust_settings.html"><strong aria-hidden="true">2.1.</strong> Rust Settings</a></li><li class="chapter-item expanded "><a href="cargo_settings.html"><strong aria-hidden="true">2.2.</strong> Cargo Settings</a></li></ol></li><li class="chapter-item expanded "><a href="rust_toolchains.html"><strong aria-hidden="true">3.</strong> Toolchains</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="rust_toolchain.html"><strong aria-hidden="true">3.1.</strong> rust_toolchain</a></li><li class="chapter-item expanded "><a href="rustfmt_toolchain.html"><strong aria-hidden="true">3.2.</strong> rustfmt_toolchain</a></li><li class="chapter-item expanded "><a href="rust_analyzer_toolchain.html"><strong aria-hidden="true">3.3.</strong> rust_analyzer_toolchain</a></li><li class="chapter-item expanded "><a href="rust_stdlib_filegroup.html"><strong aria-hidden="true">3.4.</strong> rust_stdlib_filegroup</a></li></ol></li><li class="chapter-item expanded "><a href="rust_bzlmod.html"><strong aria-hidden="true">4.</strong> Bzlmod</a></li><li class="chapter-item expanded "><a href="external_crates.html"><strong aria-hidden="true">5.</strong> External Crates</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="crate_universe_bzlmod.html"><strong aria-hidden="true">5.1.</strong> crate_universe</a></li></ol></li><li class="chapter-item expanded "><a href="coverage.html"><strong aria-hidden="true">6.</strong> Code Coverage</a></li><li class="chapter-item expanded "><a href="upstream_tooling.html"><strong aria-hidden="true">7.</strong> Upstream Tooling</a></li><li class="chapter-item expanded "><a href="ide_integrations.html"><strong aria-hidden="true">8.</strong> IDE Integrations</a></li><li class="chapter-item expanded "><a href="extensions.html"><strong aria-hidden="true">9.</strong> Extensions</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="rust_bindgen.html"><strong aria-hidden="true">9.1.</strong> bindgen</a></li><li class="chapter-item expanded "><a href="rust_mdbook.html"><strong aria-hidden="true">9.2.</strong> mdbook</a></li><li class="chapter-item expanded "><a href="rust_prost.html"><strong aria-hidden="true">9.3.</strong> prost</a></li><li class="chapter-item expanded "><a href="rust_pyo3.html"><strong aria-hidden="true">9.4.</strong> pyo3</a></li><li class="chapter-item expanded "><a href="rust_wasm_bindgen.html"><strong aria-hidden="true">9.5.</strong> wasm_bindgen</a></li></ol></li></ol>';
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
