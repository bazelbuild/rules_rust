// Copyright 2018 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

use crate::context::LicenseData;

use spdx::{
  expression::{ExprNode, Operator},
  Expression,
};

// KEEP ORDERED: The order dictates the preference.
/// The list of Bazel-known license types
#[derive(Eq, PartialEq, Ord, PartialOrd, Debug, Hash, Clone)]
pub enum BazelLicenseType {
  Unencumbered,
  Notice,
  Reciprocal,
  ByExceptionOnly,
  Restricted,
  // Not conventional, but not sure what to do in these cases
  Disallowed,
}

impl BazelLicenseType {
  pub fn to_bazel_rating(&self) -> &'static str {
    match self {
      Self::Unencumbered => "unencumbered",
      Self::Notice => "notice",
      Self::Reciprocal => "reciprocal",
      // N.B.: Bazel doesn't have a notion of "disallowed" or "by_exception_only", using restricted instead.
      Self::Restricted | Self::ByExceptionOnly | Self::Disallowed => "restricted",
    }
  }
}

/// A data structure for calculating a crate's license restrictions
#[derive(Debug)]
struct BazelSpdxLicense {
  // The name of the license this struct represents
  pub name: String,
  // The expression the node represents. At the beginning, this will be the same as name at the end
  // this will contain the entire SPDX expression for the crate's license.
  pub expression: String,
  // The license of the name field. This represents the least restrictive license for the
  // expression field.
  pub license: BazelLicenseType,
}

impl BazelSpdxLicense {
  fn combine_license_expr(license1: &Self, license2: &Self, operator: &str) -> String {
    // Surround license expressions with parenthesis if it isn't just the node name
    let expr_str1 = if license1.name != license1.expression {
      format!("({})", license1.expression)
    } else {
      license1.expression.clone()
    };

    let expr_str2 = if license2.name != license2.expression {
      format!("({})", license2.expression)
    } else {
      license2.expression.clone()
    };

    // Combine them using the operator
    format!("{} {} {}", expr_str1, operator, expr_str2)
  }

  /// Takes a BazelSpdxLicense as an argument, and returns a new BazelSpdxLicense based on the more
  /// restrictive license. If both licenses are equally restrictive, self's license is used. The
  /// new BazelSpdxLicense's expression will represent the "AND" of the two expressions.
  pub fn and(&self, other_license: Self) -> Self {
    let combined_expr = Self::combine_license_expr(self, &other_license, "AND");
    if self.license >= other_license.license {
      Self {
        name: self.name.clone(),
        expression: combined_expr,
        license: self.license.clone(),
      }
    } else {
      Self {
        name: other_license.name,
        expression: combined_expr,
        license: other_license.license,
      }
    }
  }

  /// Takes a BazelSpdxLicense as an argument, and returns a new BazelSpdxLicense based on the less
  /// restrictive license. If both licenses are equally restrictive, self's license is used. The
  /// new BazelSpdxLicense's expression will represent the "OR" of the two expressions.
  pub fn or(&self, other_license: Self) -> Self {
    let combined_expr = Self::combine_license_expr(&self, &other_license, "OR");
    if self.license <= other_license.license {
      Self {
        name: self.name.clone(),
        expression: combined_expr,
        license: self.license.clone(),
      }
    } else {
      Self {
        name: other_license.name,
        expression: combined_expr,
        license: other_license.license,
      }
    }
  }
}

/// Breaks apart a cargo license string and yields the available license types.
pub fn get_license_from_str(cargo_license_str: &str) -> LicenseData {
  if cargo_license_str.is_empty() {
    return LicenseData::default();
  }

  // Many crates have forward-slashes in their licenses. This requires Lax parsing mode
  let license_expression = match Expression::parse_mode(&cargo_license_str, spdx::ParseMode::Lax) {
    Ok(expression) => expression,
    Err(_) => {
      return LicenseData {
        name: format!(
          "{} (Failed to parse as an SPDX license string)",
          cargo_license_str
        ),
        rating: BazelLicenseType::Restricted.to_bazel_rating().into(),
      };
    },
  };

  let mut license_stack: Vec<BazelSpdxLicense> = Vec::new();
  // All of the unwraps are safe because we control the contents of the vector
  for node in license_expression.iter() {
    match node {
      ExprNode::Op(operator) => match operator {
        Operator::And => {
          let node2 = license_stack.pop().unwrap();
          let node1 = license_stack.pop().unwrap();
          license_stack.push(node1.and(node2));
        },
        Operator::Or => {
          let node2 = license_stack.pop().unwrap();
          let node1 = license_stack.pop().unwrap();
          license_stack.push(node1.or(node2));
        },
      },
      ExprNode::Req(requirement) => {
        // Unwrap is safe because there was no parse error so the license type must exist
        let req_name = requirement.req.license.id().unwrap().name;
        // Push requirement onto stack
        license_stack.push(BazelSpdxLicense {
          name: req_name.into(),
          expression: req_name.into(),
          license: get_bazel_license_type(&req_name),
        });
      },
    };
  }

  let crate_license = license_stack.pop().unwrap();
  LicenseData {
    name: format!(
      "{} from expression \"{}\"",
      crate_license.name, crate_license.expression
    ),
    rating: crate_license.license.to_bazel_rating().into(),
  }
}

fn get_bazel_license_type(license_str: &str) -> BazelLicenseType {
  match license_str {
    "AFL-2.1" => BazelLicenseType::Notice,
    "Apache-1.0" => BazelLicenseType::Notice,
    "Apache-1.1" => BazelLicenseType::Notice,
    "Apache-2.0" => BazelLicenseType::Notice,
    "Artistic-1.0" => BazelLicenseType::Notice,
    "Artistic-2.0" => BazelLicenseType::Notice,
    "BSD-1-Clause" => BazelLicenseType::Notice,
    "BSD-3-Clause" => BazelLicenseType::Notice,
    "libtiff" => BazelLicenseType::Notice,
    "BSL-1.0" => BazelLicenseType::Notice,
    "CC-BY-3.0" => BazelLicenseType::Notice,
    "CC-BY-4.0" => BazelLicenseType::Notice,
    "ISC" => BazelLicenseType::Notice,
    "LPL-1.02" => BazelLicenseType::Notice,
    "Libpng" => BazelLicenseType::Notice,
    "MIT" => BazelLicenseType::Notice,
    "MS-PL" => BazelLicenseType::Notice,
    "NCSA" => BazelLicenseType::Notice,
    "OpenSSL" => BazelLicenseType::Notice,
    "PHP-3.0" => BazelLicenseType::Notice,
    "PHP-3.01" => BazelLicenseType::Notice,
    "Python-2.0" => BazelLicenseType::Notice,
    "TCP-wrappers" => BazelLicenseType::Notice,
    "Unicode-DFS-2015" => BazelLicenseType::Notice,
    "Unicode-DFS-2016" => BazelLicenseType::Notice,
    "W3C" => BazelLicenseType::Notice,
    "W3C-19980720" => BazelLicenseType::Notice,
    "W3C-20150513" => BazelLicenseType::Notice,
    "X11" => BazelLicenseType::Notice,
    "Xnet" => BazelLicenseType::Notice,
    "ZPL-2.0" => BazelLicenseType::Notice,
    "ZPL-2.1" => BazelLicenseType::Notice,
    "Zend-2.0" => BazelLicenseType::Notice,
    "Zlib" => BazelLicenseType::Notice,
    "CC0-1.0" => BazelLicenseType::Unencumbered,
    "Unlicense" => BazelLicenseType::Unencumbered,
    "AGPL-1.0" => BazelLicenseType::Disallowed,
    "AGPL-3.0" => BazelLicenseType::Disallowed,
    "AGPL-3.0-only" => BazelLicenseType::Disallowed,
    "AGPL-3.0-or-later" => BazelLicenseType::Disallowed,
    "WTFPL" => BazelLicenseType::Disallowed,    /* unsound */
    "Beerware" => BazelLicenseType::Disallowed, /* unsound */
    "EUPL-1.0" => BazelLicenseType::Disallowed,
    "EUPL-1.1" => BazelLicenseType::Disallowed,
    "EUPL-1.2" => BazelLicenseType::Disallowed,
    "SISSL" => BazelLicenseType::Disallowed, /* unknown */
    "SISSL-1.2" => BazelLicenseType::Disallowed, /* unknown */
    "CC-BY-NC-1.0" => BazelLicenseType::Disallowed, /* non-commercial */
    "CC-BY-NC-2.0" => BazelLicenseType::Disallowed, /* non-commercial */
    "CC-BY-NC-2.5" => BazelLicenseType::Disallowed, /* non-commercial */
    "CC-BY-NC-3.0" => BazelLicenseType::Disallowed, /* non-commercial */
    "CC-BY-NC-4.0" => BazelLicenseType::Disallowed, /* non-commercial */
    "CC-BY-NC-ND-1.0" => BazelLicenseType::Disallowed, /* non-commercial */
    "CC-BY-NC-ND-2.0" => BazelLicenseType::Disallowed, /* non-commercial */
    "CC-BY-NC-ND-2.5" => BazelLicenseType::Disallowed, /* non-commercial */
    "CC-BY-NC-ND-3.0" => BazelLicenseType::Disallowed, /* non-commercial */
    "CC-BY-NC-ND-4.0" => BazelLicenseType::Disallowed, /* non-commercial */
    "CC-BY-NC-SA-1.0" => BazelLicenseType::Disallowed, /* non-commercial */
    "CC-BY-NC-SA-2.0" => BazelLicenseType::Disallowed, /* non-commercial */
    "CC-BY-NC-SA-2.5" => BazelLicenseType::Disallowed, /* non-commercial */
    "CC-BY-NC-SA-3.0" => BazelLicenseType::Disallowed, /* non-commercial */
    "CC-BY-NC-SA-4.0" => BazelLicenseType::Disallowed, /* non-commercial */
    "OFL-1.0" => BazelLicenseType::ByExceptionOnly,
    "OFL-1.1" => BazelLicenseType::ByExceptionOnly,
    "CPL-1.0" => BazelLicenseType::Reciprocal,
    "APSL-2.0" => BazelLicenseType::Reciprocal,
    "CDDL-1.0" => BazelLicenseType::Reciprocal,
    "CDDL-1.1" => BazelLicenseType::Reciprocal,
    "EPL-1.0" => BazelLicenseType::Reciprocal,
    "IPL-1.0" => BazelLicenseType::Reciprocal,
    "MPL-1.0" => BazelLicenseType::Reciprocal,
    "MPL-1.1" => BazelLicenseType::Reciprocal,
    "MPL-2.0" => BazelLicenseType::Reciprocal,
    "Ruby" => BazelLicenseType::Reciprocal,
    "0BSD" => BazelLicenseType::Restricted,     /* unknown */
    "AAL" => BazelLicenseType::Restricted,      /* unknown */
    "ADSL" => BazelLicenseType::Restricted,     /* unknown */
    "AFL-1.1" => BazelLicenseType::Restricted,  /* unknown */
    "AFL-1.2" => BazelLicenseType::Restricted,  /* unknown */
    "AFL-2.0" => BazelLicenseType::Restricted,  /* unknown */
    "AFL-3.0" => BazelLicenseType::Restricted,  /* unknown */
    "AMDPLPA" => BazelLicenseType::Restricted,  /* unknown */
    "AML" => BazelLicenseType::Restricted,      /* unknown */
    "AMPAS" => BazelLicenseType::Restricted,    /* unknown */
    "ANTLR-PD" => BazelLicenseType::Restricted, /* unknown */
    "APAFML" => BazelLicenseType::Restricted,   /* unknown */
    "APL-1.0" => BazelLicenseType::Restricted,  /* unknown */
    "APSL-1.0" => BazelLicenseType::Restricted, /* unknown */
    "APSL-1.1" => BazelLicenseType::Restricted, /* unknown */
    "APSL-1.2" => BazelLicenseType::Restricted, /* unknown */
    "Abstyles" => BazelLicenseType::Restricted, /* unknown */
    "Adobe-2006" => BazelLicenseType::Restricted, /* unknown */
    "Adobe-Glyph" => BazelLicenseType::Restricted, /* unknown */
    "Afmparse" => BazelLicenseType::Restricted, /* unknown */
    "Aladdin" => BazelLicenseType::Restricted,  /* unknown */
    "Artistic-1.0-Perl" => BazelLicenseType::Restricted, /* unknown */
    "Artistic-1.0-cl8" => BazelLicenseType::Restricted, /* unknown */
    "BSD-2-Clause" => BazelLicenseType::Restricted, /* unknown */
    "BSD-2-Clause-FreeBSD" => BazelLicenseType::Restricted, /* unknown */
    "BSD-2-Clause-NetBSD" => BazelLicenseType::Restricted, /* unknown */
    "BSD-2-Clause-Patent" => BazelLicenseType::Restricted, /* unknown */
    "BSD-3-Clause-Attribution" => BazelLicenseType::Restricted, /* unknown */
    "BSD-3-Clause-Clear" => BazelLicenseType::Restricted, /* unknown */
    "BSD-3-Clause-LBNL" => BazelLicenseType::Restricted, /* unknown */
    "BSD-3-Clause-No-Nuclear-License" => BazelLicenseType::Restricted, /* unknown */
    "BSD-3-Clause-No-Nuclear-License-2014" => BazelLicenseType::Restricted, /* unknown */
    "BSD-3-Clause-No-Nuclear-Warranty" => BazelLicenseType::Restricted, /* unknown */
    "BSD-4-Clause" => BazelLicenseType::Restricted, /* unknown */
    "BSD-4-Clause-UC" => BazelLicenseType::Restricted, /* unknown */
    "BSD-Protection" => BazelLicenseType::Restricted, /* unknown */
    "BSD-Source-Code" => BazelLicenseType::Restricted, /* unknown */
    "Bahyph" => BazelLicenseType::Restricted,   /* unknown */
    "Barr" => BazelLicenseType::Restricted,     /* unknown */
    "BitTorrent-1.0" => BazelLicenseType::Restricted, /* unknown */
    "BitTorrent-1.1" => BazelLicenseType::Restricted, /* unknown */
    "Borceux" => BazelLicenseType::Restricted,  /* unknown */
    "CATOSL-1.1" => BazelLicenseType::Restricted, /* unknown */
    "CC-BY-1.0" => BazelLicenseType::Restricted, /* unknown */
    "CC-BY-2.0" => BazelLicenseType::Restricted, /* unknown */
    "CC-BY-2.5" => BazelLicenseType::Restricted, /* unknown */
    "CC-BY-ND-1.0" => BazelLicenseType::Restricted,
    "CC-BY-ND-2.0" => BazelLicenseType::Restricted,
    "CC-BY-ND-2.5" => BazelLicenseType::Restricted,
    "CC-BY-ND-3.0" => BazelLicenseType::Restricted,
    "CC-BY-ND-4.0" => BazelLicenseType::Restricted,
    "CC-BY-SA-1.0" => BazelLicenseType::Restricted,
    "CC-BY-SA-2.0" => BazelLicenseType::Restricted,
    "CC-BY-SA-2.5" => BazelLicenseType::Restricted,
    "CC-BY-SA-3.0" => BazelLicenseType::Restricted,
    "CC-BY-SA-4.0" => BazelLicenseType::Restricted,
    "CDLA-Permissive-1.0" => BazelLicenseType::Restricted, /* unknown */
    "CDLA-Sharing-1.0" => BazelLicenseType::Restricted,    /* unknown */
    "CECILL-1.0" => BazelLicenseType::Restricted,          /* unknown */
    "CECILL-1.1" => BazelLicenseType::Restricted,          /* unknown */
    "CECILL-2.0" => BazelLicenseType::Restricted,          /* unknown */
    "CECILL-2.1" => BazelLicenseType::Restricted,          /* unknown */
    "CECILL-B" => BazelLicenseType::Restricted,            /* unknown */
    "CECILL-C" => BazelLicenseType::Restricted,            /* unknown */
    "CNRI-Jython" => BazelLicenseType::Restricted,         /* unknown */
    "CNRI-Python" => BazelLicenseType::Restricted,         /* unknown */
    "CNRI-Python-GPL-Compatible" => BazelLicenseType::Restricted, /* unknown */
    "CPAL-1.0" => BazelLicenseType::Restricted,            /* unknown */
    "CPOL-1.02" => BazelLicenseType::Restricted,           /* unknown */
    "CUA-OPL-1.0" => BazelLicenseType::Restricted,         /* unknown */
    "Caldera" => BazelLicenseType::Restricted,             /* unknown */
    "ClArtistic" => BazelLicenseType::Restricted,          /* unknown */
    "Condor-1.1" => BazelLicenseType::Restricted,          /* unknown */
    "Crossword" => BazelLicenseType::Restricted,           /* unknown */
    "CrystalStacker" => BazelLicenseType::Restricted,      /* unknown */
    "Cube" => BazelLicenseType::Restricted,                /* unknown */
    "D-FSL-1.0" => BazelLicenseType::Restricted,           /* unknown */
    "DOC" => BazelLicenseType::Restricted,                 /* unknown */
    "DSDP" => BazelLicenseType::Restricted,                /* unknown */
    "Dotseqn" => BazelLicenseType::Restricted,             /* unknown */
    "ECL-1.0" => BazelLicenseType::Restricted,             /* unknown */
    "ECL-2.0" => BazelLicenseType::Restricted,             /* unknown */
    "EFL-1.0" => BazelLicenseType::Restricted,             /* unknown */
    "EFL-2.0" => BazelLicenseType::Restricted,             /* unknown */
    "EPL-2.0" => BazelLicenseType::Restricted,             /* unknown */
    "EUDatagrid" => BazelLicenseType::Restricted,          /* unknown */
    "Entessa" => BazelLicenseType::Restricted,             /* unknown */
    "ErlPL-1.1" => BazelLicenseType::Restricted,           /* unknown */
    "Eurosym" => BazelLicenseType::Restricted,             /* unknown */
    "FSFAP" => BazelLicenseType::Restricted,               /* unknown */
    "FSFUL" => BazelLicenseType::Restricted,               /* unknown */
    "FSFULLR" => BazelLicenseType::Restricted,             /* unknown */
    "FTL" => BazelLicenseType::Restricted,                 /* unknown */
    "Fair" => BazelLicenseType::Restricted,                /* unknown */
    "Frameworx-1.0" => BazelLicenseType::Restricted,       /* unknown */
    "FreeImage" => BazelLicenseType::Restricted,           /* unknown */
    "GFDL-1.1" => BazelLicenseType::Restricted,            /* unknown */
    "GFDL-1.1-only" => BazelLicenseType::Restricted,       /* unknown */
    "GFDL-1.1-or-later" => BazelLicenseType::Restricted,   /* unknown */
    "GFDL-1.2" => BazelLicenseType::Restricted,            /* unknown */
    "GFDL-1.2-only" => BazelLicenseType::Restricted,       /* unknown */
    "GFDL-1.2-or-later" => BazelLicenseType::Restricted,   /* unknown */
    "GFDL-1.3" => BazelLicenseType::Restricted,            /* unknown */
    "GFDL-1.3-only" => BazelLicenseType::Restricted,       /* unknown */
    "GFDL-1.3-or-later" => BazelLicenseType::Restricted,   /* unknown */
    "GL2PS" => BazelLicenseType::Restricted,               /* unknown */
    "GPL-1.0" => BazelLicenseType::Restricted,
    "GPL-1.0+" => BazelLicenseType::Restricted,
    "GPL-1.0-only" => BazelLicenseType::Restricted,
    "GPL-1.0-or-later" => BazelLicenseType::Restricted,
    "GPL-2.0" => BazelLicenseType::Restricted,
    "GPL-2.0+" => BazelLicenseType::Restricted,
    "GPL-2.0-only" => BazelLicenseType::Restricted,
    "GPL-2.0-or-later" => BazelLicenseType::Restricted,
    "GPL-2.0-with-GCC-exception" => BazelLicenseType::Restricted,
    "GPL-2.0-with-autoconf-exception" => BazelLicenseType::Restricted,
    "GPL-2.0-with-bison-exception" => BazelLicenseType::Restricted,
    "GPL-2.0-with-classpath-exception" => BazelLicenseType::Restricted,
    "GPL-2.0-with-font-exception" => BazelLicenseType::Restricted,
    "GPL-3.0" => BazelLicenseType::Restricted,
    "GPL-3.0+" => BazelLicenseType::Restricted,
    "GPL-3.0-only" => BazelLicenseType::Restricted,
    "GPL-3.0-or-later" => BazelLicenseType::Restricted,
    "GPL-3.0-with-GCC-exception" => BazelLicenseType::Restricted,
    "GPL-3.0-with-autoconf-exception" => BazelLicenseType::Restricted,
    "Giftware" => BazelLicenseType::Restricted, /* unknown */
    "Glide" => BazelLicenseType::Restricted,    /* unknown */
    "Glulxe" => BazelLicenseType::Restricted,   /* unknown */
    "HPND" => BazelLicenseType::Restricted,     /* unknown */
    "HaskellReport" => BazelLicenseType::Restricted, /* unknown */
    "IBM-pibs" => BazelLicenseType::Restricted, /* unknown */
    "ICU" => BazelLicenseType::Restricted,      /* unknown */
    "IJG" => BazelLicenseType::Restricted,      /* unknown */
    "IPA" => BazelLicenseType::Restricted,      /* unknown */
    "ImageMagick" => BazelLicenseType::Restricted, /* unknown */
    "Imlib2" => BazelLicenseType::Restricted,   /* unknown */
    "Info-ZIP" => BazelLicenseType::Restricted, /* unknown */
    "Intel" => BazelLicenseType::Restricted,    /* unknown */
    "Intel-ACPI" => BazelLicenseType::Restricted, /* unknown */
    "Interbase-1.0" => BazelLicenseType::Restricted, /* unknown */
    "JSON" => BazelLicenseType::Restricted,     /* unknown */
    "JasPer-2.0" => BazelLicenseType::Restricted, /* unknown */
    "LAL-1.2" => BazelLicenseType::Restricted,  /* unknown */
    "LAL-1.3" => BazelLicenseType::Restricted,  /* unknown */
    "LGPL-2.0" => BazelLicenseType::Restricted, /* unknown */
    "LGPL-2.0+" => BazelLicenseType::Restricted, /* unknown */
    "LGPL-2.0-only" => BazelLicenseType::Restricted, /* unknown */
    "LGPL-2.0-or-later" => BazelLicenseType::Restricted, /* unknown */
    "LGPL-2.1" => BazelLicenseType::Restricted, /* unknown */
    "LGPL-2.1+" => BazelLicenseType::Restricted, /* unknown */
    "LGPL-2.1-only" => BazelLicenseType::Restricted, /* unknown */
    "LGPL-2.1-or-later" => BazelLicenseType::Restricted, /* unknown */
    "LGPL-3.0" => BazelLicenseType::Restricted, /* unknown */
    "LGPL-3.0+" => BazelLicenseType::Restricted, /* unknown */
    "LGPL-3.0-only" => BazelLicenseType::Restricted, /* unknown */
    "LGPL-3.0-or-later" => BazelLicenseType::Restricted, /* unknown */
    "LGPLLR" => BazelLicenseType::Restricted,   /* unknown */
    "LPL-1.0" => BazelLicenseType::Restricted,  /* unknown */
    "LPPL-1.0" => BazelLicenseType::Restricted, /* unknown */
    "LPPL-1.1" => BazelLicenseType::Restricted, /* unknown */
    "LPPL-1.2" => BazelLicenseType::Restricted, /* unknown */
    "LPPL-1.3a" => BazelLicenseType::Restricted, /* unknown */
    "LPPL-1.3c" => BazelLicenseType::Restricted, /* unknown */
    "Latex2e" => BazelLicenseType::Restricted,  /* unknown */
    "Leptonica" => BazelLicenseType::Restricted, /* unknown */
    "LiLiQ-P-1.1" => BazelLicenseType::Restricted, /* unknown */
    "LiLiQ-R-1.1" => BazelLicenseType::Restricted, /* unknown */
    "LiLiQ-Rplus-1.1" => BazelLicenseType::Restricted, /* unknown */
    "MIT-CMU" => BazelLicenseType::Restricted,  /* unknown */
    "MIT-advertising" => BazelLicenseType::Restricted, /* unknown */
    "MIT-enna" => BazelLicenseType::Restricted, /* unknown */
    "MIT-feh" => BazelLicenseType::Restricted,  /* unknown */
    "MITNFA" => BazelLicenseType::Restricted,   /* unknown */
    "MPL-2.0-no-copyleft-exception" => BazelLicenseType::Restricted, /* unknown */
    "MS-RL" => BazelLicenseType::Restricted,    /* unknown */
    "MTLL" => BazelLicenseType::Restricted,     /* unknown */
    "MakeIndex" => BazelLicenseType::Restricted, /* unknown */
    "MirOS" => BazelLicenseType::Restricted,    /* unknown */
    "Motosoto" => BazelLicenseType::Restricted, /* unknown */
    "Multics" => BazelLicenseType::Restricted,  /* unknown */
    "Mup" => BazelLicenseType::Restricted,      /* unknown */
    "NASA-1.3" => BazelLicenseType::Restricted, /* unknown */
    "NBPL-1.0" => BazelLicenseType::Restricted, /* unknown */
    "NGPL" => BazelLicenseType::Restricted,     /* unknown */
    "NLOD-1.0" => BazelLicenseType::Restricted, /* unknown */
    "NLPL" => BazelLicenseType::Restricted,     /* unknown */
    "NOSL" => BazelLicenseType::Restricted,     /* unknown */
    "NPL-1.0" => BazelLicenseType::Restricted,
    "NPL-1.1" => BazelLicenseType::Restricted,
    "NPOSL-3.0" => BazelLicenseType::Restricted, /* unknown */
    "NRL" => BazelLicenseType::Restricted,       /* unknown */
    "NTP" => BazelLicenseType::Restricted,       /* unknown */
    "Naumen" => BazelLicenseType::Restricted,    /* unknown */
    "Net-SNMP" => BazelLicenseType::Restricted,  /* unknown */
    "NetCDF" => BazelLicenseType::Restricted,    /* unknown */
    "Newsletr" => BazelLicenseType::Restricted,  /* unknown */
    "Nokia" => BazelLicenseType::Restricted,     /* unknown */
    "Noweb" => BazelLicenseType::Restricted,     /* unknown */
    "Nunit" => BazelLicenseType::Restricted,     /* unknown */
    "OCCT-PL" => BazelLicenseType::Restricted,   /* unknown */
    "OCLC-2.0" => BazelLicenseType::Restricted,  /* unknown */
    "ODbL-1.0" => BazelLicenseType::Restricted,  /* unknown */
    "OGTSL" => BazelLicenseType::Restricted,     /* unknown */
    "OLDAP-1.1" => BazelLicenseType::Restricted, /* unknown */
    "OLDAP-1.2" => BazelLicenseType::Restricted, /* unknown */
    "OLDAP-1.3" => BazelLicenseType::Restricted, /* unknown */
    "OLDAP-1.4" => BazelLicenseType::Restricted, /* unknown */
    "OLDAP-2.0" => BazelLicenseType::Restricted, /* unknown */
    "OLDAP-2.0.1" => BazelLicenseType::Restricted, /* unknown */
    "OLDAP-2.1" => BazelLicenseType::Restricted, /* unknown */
    "OLDAP-2.2" => BazelLicenseType::Restricted, /* unknown */
    "OLDAP-2.2.1" => BazelLicenseType::Restricted, /* unknown */
    "OLDAP-2.2.2" => BazelLicenseType::Restricted, /* unknown */
    "OLDAP-2.3" => BazelLicenseType::Restricted, /* unknown */
    "OLDAP-2.4" => BazelLicenseType::Restricted, /* unknown */
    "OLDAP-2.5" => BazelLicenseType::Restricted, /* unknown */
    "OLDAP-2.6" => BazelLicenseType::Restricted, /* unknown */
    "OLDAP-2.7" => BazelLicenseType::Restricted, /* unknown */
    "OLDAP-2.8" => BazelLicenseType::Restricted, /* unknown */
    "OML" => BazelLicenseType::Restricted,       /* unknown */
    "OPL-1.0" => BazelLicenseType::Restricted,   /* unknown */
    "OSET-PL-2.1" => BazelLicenseType::Restricted, /* unknown */
    "OSL-1.0" => BazelLicenseType::Restricted,
    "OSL-1.1" => BazelLicenseType::Restricted,
    "OSL-2.0" => BazelLicenseType::Restricted,
    "OSL-2.1" => BazelLicenseType::Restricted,
    "OSL-3.0" => BazelLicenseType::Restricted,
    "PDDL-1.0" => BazelLicenseType::Restricted, /* unknown */
    "Plexus" => BazelLicenseType::Restricted,   /* unknown */
    "PostgreSQL" => BazelLicenseType::Restricted, /* unknown */
    "QPL-1.0" => BazelLicenseType::Restricted,
    "Qhull" => BazelLicenseType::Restricted, /* unknown */
    "RHeCos-1.1" => BazelLicenseType::Restricted, /* unknown */
    "RPL-1.1" => BazelLicenseType::Restricted, /* unknown */
    "RPL-1.5" => BazelLicenseType::Restricted, /* unknown */
    "RPSL-1.0" => BazelLicenseType::Restricted, /* unknown */
    "RSA-MD" => BazelLicenseType::Restricted, /* unknown */
    "RSCPL" => BazelLicenseType::Restricted, /* unknown */
    "Rdisc" => BazelLicenseType::Restricted, /* unknown */
    "SAX-PD" => BazelLicenseType::Restricted, /* unknown */
    "SCEA" => BazelLicenseType::Restricted,  /* unknown */
    "SGI-B-1.0" => BazelLicenseType::Restricted, /* unknown */
    "SGI-B-1.1" => BazelLicenseType::Restricted, /* unknown */
    "SGI-B-2.0" => BazelLicenseType::Restricted, /* unknown */
    "SMLNJ" => BazelLicenseType::Restricted, /* unknown */
    "SMPPL" => BazelLicenseType::Restricted, /* unknown */
    "SNIA" => BazelLicenseType::Restricted,  /* unknown */
    "SPL-1.0" => BazelLicenseType::Restricted, /* unknown */
    "SWL" => BazelLicenseType::Restricted,   /* unknown */
    "Saxpath" => BazelLicenseType::Restricted, /* unknown */
    "Sendmail" => BazelLicenseType::Restricted, /* unknown */
    "SimPL-2.0" => BazelLicenseType::Restricted, /* unknown */
    "Sleepycat" => BazelLicenseType::Restricted,
    "Spencer-86" => BazelLicenseType::Restricted, /* unknown */
    "Spencer-94" => BazelLicenseType::Restricted, /* unknown */
    "Spencer-99" => BazelLicenseType::Restricted, /* unknown */
    "StandardML-NJ" => BazelLicenseType::Restricted, /* unknown */
    "SugarCRM-1.1.3" => BazelLicenseType::Restricted, /* unknown */
    "TCL" => BazelLicenseType::Restricted,        /* unknown */
    "TMate" => BazelLicenseType::Restricted,      /* unknown */
    "TORQUE-1.1" => BazelLicenseType::Restricted, /* unknown */
    "TOSL" => BazelLicenseType::Restricted,       /* unknown */
    "UPL-1.0" => BazelLicenseType::Restricted,    /* unknown */
    "Unicode-TOU" => BazelLicenseType::Restricted, /* unknown */
    "VOSTROM" => BazelLicenseType::Restricted,    /* unknown */
    "VSL-1.0" => BazelLicenseType::Restricted,    /* unknown */
    "Vim" => BazelLicenseType::Restricted,        /* unknown */
    "Watcom-1.0" => BazelLicenseType::Restricted, /* unknown */
    "Wsuipa" => BazelLicenseType::Restricted,     /* unknown */
    "XFree86-1.1" => BazelLicenseType::Restricted, /* unknown */
    "XSkat" => BazelLicenseType::Restricted,      /* unknown */
    "Xerox" => BazelLicenseType::Restricted,      /* unknown */
    "YPL-1.0" => BazelLicenseType::Restricted,    /* unknown */
    "YPL-1.1" => BazelLicenseType::Restricted,    /* unknown */
    "ZPL-1.1" => BazelLicenseType::Restricted,    /* unknown */
    "Zed" => BazelLicenseType::Restricted,        /* unknown */
    "Zimbra-1.3" => BazelLicenseType::Restricted, /* unknown */
    "Zimbra-1.4" => BazelLicenseType::Restricted, /* unknown */
    "bzip2-1.0.5" => BazelLicenseType::Restricted, /* unknown */
    "bzip2-1.0.6" => BazelLicenseType::Restricted, /* unknown */
    "curl" => BazelLicenseType::Restricted,       /* unknown */
    "diffmark" => BazelLicenseType::Restricted,   /* unknown */
    "dvipdfm" => BazelLicenseType::Restricted,    /* unknown */
    "eCos-2.0" => BazelLicenseType::Restricted,   /* unknown */
    "eGenix" => BazelLicenseType::Restricted,     /* unknown */
    "gSOAP-1.3b" => BazelLicenseType::Restricted, /* unknown */
    "gnuplot" => BazelLicenseType::Restricted,    /* unknown */
    "iMatix" => BazelLicenseType::Restricted,     /* unknown */
    "mpich2" => BazelLicenseType::Restricted,     /* unknown */
    "psfrag" => BazelLicenseType::Restricted,     /* unknown */
    "psutils" => BazelLicenseType::Restricted,    /* unknown */
    "wxWindows" => BazelLicenseType::Restricted,  /* unknown */
    "xinetd" => BazelLicenseType::Restricted,     /* unknown */
    "xpp" => BazelLicenseType::Restricted,        /* unknown */
    "zlib-acknowledgement" => BazelLicenseType::Restricted, /* unknown */
    _ => BazelLicenseType::Restricted,
  }
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn more_permissive_licenses_come_first_with_or() {
    let license = get_license_from_str("Unlicense/Apache-2.0");
    assert_eq!(
      license.name,
      "Unlicense from expression \"Unlicense OR Apache-2.0\""
    );
    assert_eq!(license.rating, "unencumbered");

    let flipped_license = get_license_from_str("Apache-2.0/Unlicense");
    assert_eq!(
      flipped_license.name,
      "Unlicense from expression \"Apache-2.0 OR Unlicense\""
    );
    assert_eq!(flipped_license.rating, "unencumbered");
  }

  #[test]
  fn less_permissive_licenses_come_first_with_and() {
    let license = get_license_from_str("Unlicense AND Apache-2.0");
    assert_eq!(
      license.name,
      "Apache-2.0 from expression \"Unlicense AND Apache-2.0\""
    );
    assert_eq!(license.rating, "notice");

    let flipped_license = get_license_from_str("Apache-2.0 AND Unlicense");
    assert_eq!(
      flipped_license.name,
      "Apache-2.0 from expression \"Apache-2.0 AND Unlicense\""
    );
    assert_eq!(flipped_license.rating, "notice");
  }

  #[test]
  fn chained_or_works_properly() {
    let license = get_license_from_str("MIT OR Apache-2.0 OR Unlicense");
    assert_eq!(
      license.name,
      "Unlicense from expression \"MIT OR (Apache-2.0 OR Unlicense)\""
    );
    assert_eq!(license.rating, "unencumbered");
  }

  #[test]
  fn unknown_licenses_are_restricted() {
    let license = get_license_from_str("MIT5.0");
    assert_eq!(
      license.name,
      "MIT5.0 (Failed to parse as an SPDX license string)"
    );
    assert_eq!(license.rating, "restricted");
  }

  #[test]
  fn whitespace_laden_licenses_are_ok() {
    let license = get_license_from_str("MIT / Apache-2.0");
    assert_eq!(license.name, "MIT from expression \"MIT OR Apache-2.0\"");
    assert_eq!(license.rating, "notice");
  }

  #[test]
  fn empty_license_is_restricted() {
    let license = get_license_from_str("");
    assert_eq!(license.name, "no license");
    assert_eq!(license.rating, "restricted");
  }
}
