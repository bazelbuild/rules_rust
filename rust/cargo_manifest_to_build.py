#!/usr/bin/env python
import sys
import json
import subprocess
import argparse
import StringIO

parser = argparse.ArgumentParser()
parser.add_argument('dep', nargs='*',
                    help='List of dep_name=dep_version resolved versions')
parser.add_argument('--dep_format', default='@io_crates_{name}__{version}//:{name}',
                    help='How to format a dependency')
parser.add_argument('--data', required=False,
                    help='Content of the data file')
parser.add_argument('--flag', action='append', default=[],
                    help='Extra arguments for compilation')
parser.add_argument('--output',
                    type=argparse.FileType('w'),
                    default=sys.stdout,
                    help='output file')

LICENSE_TYPES = {
    "AFL-2.1": "notice",
    "Apache-1.0": "notice",
    "Apache-1.1": "notice",
    "Apache-2.0": "notice",
    "Artistic-1.0": "notice",
    "Artistic-2.0": "notice",
    "BSD-1-Clause": "notice",
    "BSD-3-Clause": "notice",
    "libtiff": "notice",
    "BSL-1.0": "notice",
    "CC-BY-3.0": "notice",
    "CC-BY-4.0": "notice",
    "ISC": "notice",
    "LPL-1.02": "notice",
    "Libpng": "notice",
    "MIT": "notice",
    "MS-PL": "notice",
    "NCSA": "notice",
    "OpenSSL": "notice",
    "PHP-3.0": "notice",
    "PHP-3.01": "notice",
    "Python-2.0": "notice",
    "TCP-wrappers": "notice",
    "Unicode-DFS-2015": "notice",
    "Unicode-DFS-2016": "notice",
    "W3C": "notice",
    "W3C-19980720": "notice",
    "W3C-20150513": "notice",
    "X11": "notice",
    "Xnet": "notice",
    "ZPL-2.0": "notice",
    "ZPL-2.1": "notice",
    "Zend-2.0": "notice",
    "Zlib": "notice",
    "CC0-1.0": "unencumbered",
    "Unlicense": "unencumbered",
    "AGPL-1.0": "restricted",
    "AGPL-3.0": "restricted",
    "AGPL-3.0-only": "restricted",
    "AGPL-3.0-or-later": "restricted",
    "WTFPL": "restricted",   
    "Beerware": "restricted",
    "EUPL-1.0": "restricted",
    "EUPL-1.1": "restricted",
    "EUPL-1.2": "restricted",
    "SISSL": "restricted",
    "SISSL-1.2": "restricted",
    "CC-BY-NC-1.0": "restricted",
    "CC-BY-NC-2.0": "restricted",
    "CC-BY-NC-2.5": "restricted",
    "CC-BY-NC-3.0": "restricted",
    "CC-BY-NC-4.0": "restricted",
    "CC-BY-NC-ND-1.0": "restricted",
    "CC-BY-NC-ND-2.0": "restricted",
    "CC-BY-NC-ND-2.5": "restricted",
    "CC-BY-NC-ND-3.0": "restricted",
    "CC-BY-NC-ND-4.0": "restricted",
    "CC-BY-NC-SA-1.0": "restricted",
    "CC-BY-NC-SA-2.0": "restricted",
    "CC-BY-NC-SA-2.5": "restricted",
    "CC-BY-NC-SA-3.0": "restricted",
    "CC-BY-NC-SA-4.0": "restricted",
    "OFL-1.0": "restricted",
    "OFL-1.1": "restricted",
    "CPL-1.0": "reciprocal",
    "APSL-2.0": "reciprocal",
    "CDDL-1.0": "reciprocal",
    "CDDL-1.1": "reciprocal",
    "EPL-1.0": "reciprocal",
    "IPL-1.0": "reciprocal",
    "MPL-1.0": "reciprocal",
    "MPL-1.1": "reciprocal",
    "MPL-2.0": "reciprocal",
    "Ruby": "reciprocal",
    "0BSD": "restricted",    
    "AAL": "restricted",     
    "ADSL": "restricted",    
    "AFL-1.1": "restricted", 
    "AFL-1.2": "restricted", 
    "AFL-2.0": "restricted", 
    "AFL-3.0": "restricted", 
    "AMDPLPA": "restricted", 
    "AML": "restricted",     
    "AMPAS": "restricted",   
    "ANTLR-PD": "restricted",
    "APAFML": "restricted",  
    "APL-1.0": "restricted", 
    "APSL-1.0": "restricted",
    "APSL-1.1": "restricted",
    "APSL-1.2": "restricted",
    "Abstyles": "restricted",
    "Adobe-2006": "restricted",
    "Adobe-Glyph": "restricted",
    "Afmparse": "restricted",
    "Aladdin": "restricted", 
    "Artistic-1.0-Perl": "restricted",
    "Artistic-1.0-cl8": "restricted",
    "BSD-2-Clause": "restricted",
    "BSD-2-Clause-FreeBSD": "restricted",
    "BSD-2-Clause-NetBSD": "restricted",
    "BSD-2-Clause-Patent": "restricted",
    "BSD-3-Clause-Attribution": "restricted",
    "BSD-3-Clause-Clear": "restricted",
    "BSD-3-Clause-LBNL": "restricted",
    "BSD-3-Clause-No-Nuclear-License": "restricted",
    "BSD-3-Clause-No-Nuclear-License-2014": "restricted",
    "BSD-3-Clause-No-Nuclear-Warranty": "restricted",
    "BSD-4-Clause": "restricted",
    "BSD-4-Clause-UC": "restricted",
    "BSD-Protection": "restricted",
    "BSD-Source-Code": "restricted",
    "Bahyph": "restricted",  
    "Barr": "restricted",    
    "BitTorrent-1.0": "restricted",
    "BitTorrent-1.1": "restricted",
    "Borceux": "restricted", 
    "CATOSL-1.1": "restricted",
    "CC-BY-1.0": "restricted",
    "CC-BY-2.0": "restricted",
    "CC-BY-2.5": "restricted",
    "CC-BY-ND-1.0": "restricted",
    "CC-BY-ND-2.0": "restricted",
    "CC-BY-ND-2.5": "restricted",
    "CC-BY-ND-3.0": "restricted",
    "CC-BY-ND-4.0": "restricted",
    "CC-BY-SA-1.0": "restricted",
    "CC-BY-SA-2.0": "restricted",
    "CC-BY-SA-2.5": "restricted",
    "CC-BY-SA-3.0": "restricted",
    "CC-BY-SA-4.0": "restricted",
    "CDLA-Permissive-1.0": "restricted",
    "CDLA-Sharing-1.0": "restricted",   
    "CECILL-1.0": "restricted",         
    "CECILL-1.1": "restricted",         
    "CECILL-2.0": "restricted",         
    "CECILL-2.1": "restricted",         
    "CECILL-B": "restricted",           
    "CECILL-C": "restricted",           
    "CNRI-Jython": "restricted",        
    "CNRI-Python": "restricted",        
    "CNRI-Python-GPL-Compatible": "restricted",
    "CPAL-1.0": "restricted",           
    "CPOL-1.02": "restricted",          
    "CUA-OPL-1.0": "restricted",        
    "Caldera": "restricted",            
    "ClArtistic": "restricted",         
    "Condor-1.1": "restricted",         
    "Crossword": "restricted",          
    "CrystalStacker": "restricted",     
    "Cube": "restricted",               
    "D-FSL-1.0": "restricted",          
    "DOC": "restricted",                
    "DSDP": "restricted",               
    "Dotseqn": "restricted",            
    "ECL-1.0": "restricted",            
    "ECL-2.0": "restricted",            
    "EFL-1.0": "restricted",            
    "EFL-2.0": "restricted",            
    "EPL-2.0": "restricted",            
    "EUDatagrid": "restricted",         
    "Entessa": "restricted",            
    "ErlPL-1.1": "restricted",          
    "Eurosym": "restricted",            
    "FSFAP": "restricted",              
    "FSFUL": "restricted",              
    "FSFULLR": "restricted",            
    "FTL": "restricted",                
    "Fair": "restricted",               
    "Frameworx-1.0": "restricted",      
    "FreeImage": "restricted",          
    "GFDL-1.1": "restricted",           
    "GFDL-1.1-only": "restricted",      
    "GFDL-1.1-or-later": "restricted",  
    "GFDL-1.2": "restricted",           
    "GFDL-1.2-only": "restricted",      
    "GFDL-1.2-or-later": "restricted",  
    "GFDL-1.3": "restricted",           
    "GFDL-1.3-only": "restricted",      
    "GFDL-1.3-or-later": "restricted",  
    "GL2PS": "restricted",              
    "GPL-1.0": "restricted",
    "GPL-1.0+": "restricted",
    "GPL-1.0-only": "restricted",
    "GPL-1.0-or-later": "restricted",
    "GPL-2.0": "restricted",
    "GPL-2.0+": "restricted",
    "GPL-2.0-only": "restricted",
    "GPL-2.0-or-later": "restricted",
    "GPL-2.0-with-GCC-exception": "restricted",
    "GPL-2.0-with-autoconf-exception": "restricted",
    "GPL-2.0-with-bison-exception": "restricted",
    "GPL-2.0-with-classpath-exception": "restricted",
    "GPL-2.0-with-font-exception": "restricted",
    "GPL-3.0": "restricted",
    "GPL-3.0+": "restricted",
    "GPL-3.0-only": "restricted",
    "GPL-3.0-or-later": "restricted",
    "GPL-3.0-with-GCC-exception": "restricted",
    "GPL-3.0-with-autoconf-exception": "restricted",
    "Giftware": "restricted",
    "Glide": "restricted",   
    "Glulxe": "restricted",  
    "HPND": "restricted",    
    "HaskellReport": "restricted",
    "IBM-pibs": "restricted",
    "ICU": "restricted",     
    "IJG": "restricted",     
    "IPA": "restricted",     
    "ImageMagick": "restricted",
    "Imlib2": "restricted",  
    "Info-ZIP": "restricted",
    "Intel": "restricted",   
    "Intel-ACPI": "restricted",
    "Interbase-1.0": "restricted",
    "JSON": "restricted",    
    "JasPer-2.0": "restricted",
    "LAL-1.2": "restricted", 
    "LAL-1.3": "restricted", 
    "LGPL-2.0": "restricted",
    "LGPL-2.0+": "restricted",
    "LGPL-2.0-only": "restricted",
    "LGPL-2.0-or-later": "restricted",
    "LGPL-2.1": "restricted",
    "LGPL-2.1+": "restricted",
    "LGPL-2.1-only": "restricted",
    "LGPL-2.1-or-later": "restricted",
    "LGPL-3.0": "restricted",
    "LGPL-3.0+": "restricted",
    "LGPL-3.0-only": "restricted",
    "LGPL-3.0-or-later": "restricted",
    "LGPLLR": "restricted",  
    "LPL-1.0": "restricted", 
    "LPPL-1.0": "restricted",
    "LPPL-1.1": "restricted",
    "LPPL-1.2": "restricted",
    "LPPL-1.3a": "restricted",
    "LPPL-1.3c": "restricted",
    "Latex2e": "restricted", 
    "Leptonica": "restricted",
    "LiLiQ-P-1.1": "restricted",
    "LiLiQ-R-1.1": "restricted",
    "LiLiQ-Rplus-1.1": "restricted",
    "MIT-CMU": "restricted", 
    "MIT-advertising": "restricted",
    "MIT-enna": "restricted",
    "MIT-feh": "restricted", 
    "MITNFA": "restricted",  
    "MPL-2.0-no-copyleft-exception": "restricted",
    "MS-RL": "restricted",   
    "MTLL": "restricted",    
    "MakeIndex": "restricted",
    "MirOS": "restricted",   
    "Motosoto": "restricted",
    "Multics": "restricted", 
    "Mup": "restricted",     
    "NASA-1.3": "restricted",
    "NBPL-1.0": "restricted",
    "NGPL": "restricted",    
    "NLOD-1.0": "restricted",
    "NLPL": "restricted",    
    "NOSL": "restricted",    
    "NPL-1.0": "restricted",
    "NPL-1.1": "restricted",
    "NPOSL-3.0": "restricted",
    "NRL": "restricted",      
    "NTP": "restricted",      
    "Naumen": "restricted",   
    "Net-SNMP": "restricted", 
    "NetCDF": "restricted",   
    "Newsletr": "restricted", 
    "Nokia": "restricted",    
    "Noweb": "restricted",    
    "Nunit": "restricted",    
    "OCCT-PL": "restricted",  
    "OCLC-2.0": "restricted", 
    "ODbL-1.0": "restricted", 
    "OGTSL": "restricted",    
    "OLDAP-1.1": "restricted",
    "OLDAP-1.2": "restricted",
    "OLDAP-1.3": "restricted",
    "OLDAP-1.4": "restricted",
    "OLDAP-2.0": "restricted",
    "OLDAP-2.0.1": "restricted",
    "OLDAP-2.1": "restricted",
    "OLDAP-2.2": "restricted",
    "OLDAP-2.2.1": "restricted",
    "OLDAP-2.2.2": "restricted",
    "OLDAP-2.3": "restricted",
    "OLDAP-2.4": "restricted",
    "OLDAP-2.5": "restricted",
    "OLDAP-2.6": "restricted",
    "OLDAP-2.7": "restricted",
    "OLDAP-2.8": "restricted",
    "OML": "restricted",      
    "OPL-1.0": "restricted",  
    "OSET-PL-2.1": "restricted",
    "OSL-1.0": "restricted",
    "OSL-1.1": "restricted",
    "OSL-2.0": "restricted",
    "OSL-2.1": "restricted",
    "OSL-3.0": "restricted",
    "PDDL-1.0": "restricted",
    "Plexus": "restricted",  
    "PostgreSQL": "restricted",
    "QPL-1.0": "restricted",
    "Qhull": "restricted",
    "RHeCos-1.1": "restricted",
    "RPL-1.1": "restricted",
    "RPL-1.5": "restricted",
    "RPSL-1.0": "restricted",
    "RSA-MD": "restricted",
    "RSCPL": "restricted",
    "Rdisc": "restricted",
    "SAX-PD": "restricted",
    "SCEA": "restricted", 
    "SGI-B-1.0": "restricted",
    "SGI-B-1.1": "restricted",
    "SGI-B-2.0": "restricted",
    "SMLNJ": "restricted",
    "SMPPL": "restricted",
    "SNIA": "restricted", 
    "SPL-1.0": "restricted",
    "SWL": "restricted",  
    "Saxpath": "restricted",
    "Sendmail": "restricted",
    "SimPL-2.0": "restricted",
    "Sleepycat": "restricted",
    "Spencer-86": "restricted",
    "Spencer-94": "restricted",
    "Spencer-99": "restricted",
    "StandardML-NJ": "restricted",
    "SugarCRM-1.1.3": "restricted",
    "TCL": "restricted",       
    "TMate": "restricted",     
    "TORQUE-1.1": "restricted",
    "TOSL": "restricted",      
    "UPL-1.0": "restricted",   
    "Unicode-TOU": "restricted",
    "VOSTROM": "restricted",   
    "VSL-1.0": "restricted",   
    "Vim": "restricted",       
    "Watcom-1.0": "restricted",
    "Wsuipa": "restricted",    
    "XFree86-1.1": "restricted",
    "XSkat": "restricted",     
    "Xerox": "restricted",     
    "YPL-1.0": "restricted",   
    "YPL-1.1": "restricted",   
    "ZPL-1.1": "restricted",   
    "Zed": "restricted",       
    "Zimbra-1.3": "restricted",
    "Zimbra-1.4": "restricted",
    "bzip2-1.0.5": "restricted",
    "bzip2-1.0.6": "restricted",
    "curl": "restricted",      
    "diffmark": "restricted",  
    "dvipdfm": "restricted",   
    "eCos-2.0": "restricted",  
    "eGenix": "restricted",    
    "gSOAP-1.3b": "restricted",
    "gnuplot": "restricted",   
    "iMatix": "restricted",    
    "mpich2": "restricted",    
    "psfrag": "restricted",    
    "psutils": "restricted",   
    "wxWindows": "restricted", 
    "xinetd": "restricted",    
    "xpp": "restricted",       
    "zlib-acknowledgement": "restricted",
}

def license_type(license):
    return LICENSE_TYPES[license] if license in LICENSE_TYPES else "restricted"

def licenses(json):
    result = []
    if "license" in json and json["license"]:
        for license in json["license"].split("/"):
            result.append("    \"%s\",  # \"%s\"" % (license_type(license), license))
    return "\n".join(result)

def remove_path_prefix(s, prefix):
    res = s[len(prefix):] if s.startswith(prefix) else s
    return res[1:] if res.startswith("/") else res

def rust_library(target, context):
    return """rust_library(
    name = "{name}",
    crate_root = "{path}",
    crate_type = "{kind}",
    srcs = glob(["**/*.rs"]),
    deps = [{deps}],
    rustc_flags = [
        "--cap-lints allow",{flags}
    ],{other}
    version = "{version}",
    crate_features = [{features}],
)""".format(
    name=target["name"].replace("-", "_"),
    path=remove_path_prefix(target["src_path"], context["workspace_root"]),
    kind=target["crate_types"][0],
    deps=context["deps"],
    flags="".join(["\n        \"%s\"," % f for f in context["flags"]]),
    other=context["other"],
    version=context["version"],
    features=",".join("\"%s\"" % f for f in context["features"]),
)

def rust_binary(target, context):
    return """rust_binary(
    name = "{name}_bin",
    crate_root = "{path}",
    srcs = glob(["**/*.rs"]),
    deps = [":{name}", {deps}],
    rustc_flags = [
        "--cap-lints allow",{flags}
    ],{other}
    version = "{version}",
    crate_features = [{features}],
)""".format(
    name=target["name"].replace("-", "_"),
    path=remove_path_prefix(target["src_path"], context["workspace_root"]),
    deps=context["deps"],
    flags="".join(["\n        \"%s\"," % f for f in context["flags"]]),
    other=context["other"],
    version=context["version"],
    features=",".join("\"%s\"" % f for f in context["features"]),
)

def custom_build_script(target, context):
    return """rust_binary(
    name = "{name}_build_script",
    crate_root = "{path}",
    srcs = glob(["**/*.rs"]),
    deps = [{build_deps}],
    rustc_flags = ["--cap-lints allow"],
    version = "{version}",
    crate_features = [{features}],
    visibility = ["//visibility:private"],
)

cargo_build_script_run(
    name = "{name}_build_script_executor",
    srcs = glob(["*", "**/*.rs"]),
    script = ":{name}_build_script",
    features = [{features}],
)
""".format(
    name=context["name"].replace("-", "_"),
    path=remove_path_prefix(target["src_path"] or "build.rs", context["workspace_root"]),
    build_deps=context["build_deps"],
    features=",".join("\"%s\"" % f for f in context["features"]),
    version=context["version"],
)

def resolve_deps(deps, ctxt):
    return ",".join([
        "\"%s\"" % ctxt["dep_format"].format(
            name=d["name"].replace("-", "_"),
            version=ctxt["resolved_deps"][d["name"]].replace(".", "_")
        )
        for d in deps
        if d["name"] in ctxt["resolved_deps"]
        ])

def extend_context(ctxt, json):
    out_dir_tar = ""
    if any([t["kind"] == ["custom-build"]] for t in json["targets"]):
        out_dir_tar = "\n    out_dir_tar = \":%s_build_script_executor\"," % json["name"].replace("-", "_")
    data = ""
    if ctxt["data"]:
        data = "\n    data = r\"\"\"%s\"\"\"," % ctxt["data"]
    for d in json["dependencies"]:
        if d["name"] not in ctxt["resolved_deps"]:
            sys.stderr.write("WARNING: Cannot resolve dependency on crate '%s'\n" % d["name"])
    return {
        "name": json["name"],
        "workspace_root": ctxt["workspace_root"],
        "flags": ctxt["flags"],
        "version": json["version"],
        "other": "%s%s" % (out_dir_tar, data),
        "deps": resolve_deps([d for d in json["dependencies"] if not d["kind"]], ctxt),
        "build_deps": resolve_deps([d for d in json["dependencies"] if d["kind"] == "build"], ctxt),
        "features": json["features"].keys(),
    }

def to_build_file(ctxt, json):
    result = ["""
package(default_visibility = ["//visibility:public"])

licenses([
%s
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
)
load(
    "@io_bazel_rules_rust//rust:crate_repository.bzl",
    "cargo_build_script_run",
)
""" % licenses(json)]
    context = extend_context(ctxt, json)
    for target in json["targets"]:
        if target["kind"][0] in ["lib", "proc-macro", "dylib", "rlib"]:
            result.append(rust_library(target, context))
        elif target["kind"][0] == "bin":
            result.append(rust_binary(target, context))
        elif target["kind"][0] == "custom-build":
            result.append(custom_build_script(target, context))
        else:
            result.append("# Unsupported target %s with type %s omitted" % (target["name"], target["kind"][0]))
    return "\n\n".join(result)

def parse_args_and_build_context(json):
    args = parser.parse_args()
    ctxt = {
        "workspace_root": json["workspace_root"],
        "data": args.data,
        "dep_format": args.dep_format,
        "resolved_deps": {v.split("=", 1)[0]: v.split("=", 1)[1] for v in args.dep},
        "output": args.output,
        "flags": args.flag or [],
    }
    return ctxt

if __name__ == "__main__":
    json = json.load(StringIO.StringIO(subprocess.check_output([
        "cargo",
        "metadata",
        "--no-deps",
        "--format-version",
        "1"
    ])))
    ctxt = parse_args_and_build_context(json)
    ctxt["output"].write(to_build_file(ctxt, json["packages"][0]))
    ctxt["output"].close()