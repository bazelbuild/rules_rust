//! Bazel label parsing library.
//!
//! USAGE: `label::analyze("//foo/bar:baz")
mod label_error;
use label_error::LabelError;

/// Parse and analyze given str.
///
/// TODO: validate . and .. in target name
/// TODO: validate used characters in target name
pub fn analyze(input: &'_ str) -> Result<Label<'_>> {
    let label = input;
    let (input, repository_name) = consume_repository_name(input, label)?;
    let (input, package_name) = consume_package_name(input, label)?;
    let name = consume_name(input, label)?;
    let name = match (package_name, name) {
        (None, None) => {
            return Err(LabelError(err(
                label,
                "labels must have a package and/or a name.",
            )))
        }
        (Some(package_name), None) => name_from_package(package_name),
        (_, Some(name)) => name,
    };
    Ok(Label::new(repository_name, package_name, name))
}

#[derive(Debug, PartialEq, Eq)]
pub struct Label<'s> {
    pub repository_name: Option<&'s str>,
    pub package_name: Option<&'s str>,
    pub name: &'s str,
}

type Result<T, E = LabelError> = core::result::Result<T, E>;

impl<'s> Label<'s> {
    fn new(
        repository_name: Option<&'s str>,
        package_name: Option<&'s str>,
        name: &'s str,
    ) -> Label<'s> {
        Label {
            repository_name,
            package_name,
            name,
        }
    }

    pub fn packages(&self) -> Vec<&'s str> {
        match self.package_name {
            Some(name) => name.split('/').collect(),
            None => vec![],
        }
    }
}

fn err<'s>(label: &'s str, msg: &'s str) -> String {
    let mut err_msg = label.to_string();
    err_msg.push_str(" must be a legal label; ");
    err_msg.push_str(msg);
    err_msg
}

fn consume_repository_name<'s>(
    input: &'s str,
    label: &'s str,
) -> Result<(&'s str, Option<&'s str>)> {
    if !input.starts_with('@') {
        return Ok((input, None));
    }

    let slash_pos = input
        .find("//")
        .ok_or_else(|| err(label, "labels with repository must contain //."))?;
    let repository_name = &input[1..slash_pos];
    if repository_name.is_empty() {
        return Ok((&input[1..], None));
    }
    if !repository_name
        .chars()
        .next()
        .unwrap()
        .is_ascii_alphabetic()
    {
        return Err(LabelError(err(
            label,
            "workspace names must start with a letter.",
        )));
    }
    if !repository_name
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_' || c == '.')
    {
        return Err(LabelError(err(
            label,
            "workspace names \
                may contain only A-Z, a-z, 0-9, '-', '_', and '.'.",
        )));
    }
    Ok((&input[slash_pos..], Some(repository_name)))
}

fn consume_package_name<'s>(input: &'s str, label: &'s str) -> Result<(&'s str, Option<&'s str>)> {
    let is_absolute = match input.rfind("//") {
        None => false,
        Some(0) => true,
        Some(_) => {
            return Err(LabelError(err(
                label,
                "'//' cannot appear in the middle of the label.",
            )));
        }
    };

    let (package_name, rest) = match (is_absolute, input.find(':')) {
        (false, colon_pos) if colon_pos.map_or(true, |pos| pos != 0) => {
            return Err(LabelError(err(
                label,
                "relative packages are not permitted.",
            )));
        }
        (_, colon_pos) => {
            let (input, colon_pos) = if is_absolute {
                (&input[2..], colon_pos.map(|cp| cp - 2))
            } else {
                (input, colon_pos)
            };
            match colon_pos {
                Some(colon_pos) => (&input[0..colon_pos], &input[colon_pos..]),
                None => (input, ""),
            }
        }
    };

    if package_name.is_empty() {
        return Ok((rest, None));
    }

    if !package_name.chars().all(|c| {
        c.is_ascii_alphanumeric()
            || c == '/'
            || c == '-'
            || c == '.'
            || c == ' '
            || c == '$'
            || c == '('
            || c == ')'
            || c == '_'
            || c == '+'
    }) {
        return Err(LabelError(err(
            label,
            "package names may contain only A-Z, \
        a-z, 0-9, '/', '-', '.', ' ', '$', '(', ')', '_', and '+'.",
        )));
    }
    if package_name.ends_with('/') {
        return Err(LabelError(err(
            label,
            "package names may not end with '/'.",
        )));
    }

    if rest.is_empty() && is_absolute {
        // This label doesn't contain the target name, we have to use
        // last segment of the package name as target name.
        return Ok((
            match package_name.rfind('/') {
                Some(pos) => &package_name[pos..],
                None => package_name,
            },
            Some(package_name),
        ));
    }

    Ok((rest, Some(package_name)))
}

fn consume_name<'s>(input: &'s str, label: &'s str) -> Result<Option<&'s str>> {
    if input.is_empty() {
        return Ok(None);
    }
    if input == ":" {
        return Err(LabelError(err(label, "empty target name.")));
    }
    let name = input
        .strip_prefix(':')
        .or_else(|| input.strip_prefix('/'))
        .unwrap_or(input);
    if name.starts_with('/') {
        return Err(LabelError(err(
            label,
            "target names may not start with '/'.",
        )));
    }
    Ok(Some(name))
}

fn name_from_package(package_name: &str) -> &str {
    package_name
        .rsplit_once('/')
        .map(|tup| tup.1)
        .unwrap_or(package_name)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new() {
        assert_eq!(
            Label::new(Some("repo"), Some("foo/bar"), "baz"),
            Label {
                repository_name: Some("repo"),
                package_name: Some("foo/bar"),
                name: "baz",
            }
        );
    }

    #[test]
    fn test_repository_name_parsing() -> Result<()> {
        assert_eq!(analyze("@repo//:foo")?.repository_name, Some("repo"));
        assert_eq!(analyze("@//:foo")?.repository_name, None);
        assert_eq!(analyze("//:foo")?.repository_name, None);
        assert_eq!(analyze(":foo")?.repository_name, None);

        assert_eq!(analyze("@repo//foo/bar")?.repository_name, Some("repo"));
        assert_eq!(analyze("@//foo/bar")?.repository_name, None);
        assert_eq!(analyze("//foo/bar")?.repository_name, None);
        assert_eq!(
            analyze("foo/bar"),
            Err(LabelError(
                "foo/bar must be a legal label; relative packages are not permitted.".to_string()
            ))
        );

        assert_eq!(analyze("@repo//foo")?.repository_name, Some("repo"));
        assert_eq!(analyze("@//foo")?.repository_name, None);
        assert_eq!(analyze("//foo")?.repository_name, None);
        assert_eq!(
            analyze("foo"),
            Err(LabelError(
                "foo must be a legal label; relative packages are not permitted.".to_string()
            ))
        );

        assert_eq!(
            analyze("@foo:bar"),
            Err(LabelError(
                "@foo:bar must be a legal label; labels with repository must contain //."
                    .to_string()
            ))
        );

        assert_eq!(
            analyze("@AZab0123456789_-.//:foo")?.repository_name,
            Some("AZab0123456789_-.")
        );
        assert_eq!(
            analyze("@42//:baz"),
            Err(LabelError(
                "@42//:baz must be a legal label; workspace names must \
            start with a letter."
                    .to_string()
            ))
        );
        assert_eq!(
            analyze("@foo#//:baz"),
            Err(LabelError(
                "@foo#//:baz must be a legal label; workspace names \
            may contain only A-Z, a-z, 0-9, '-', '_', and '.'."
                    .to_string()
            ))
        );
        Ok(())
    }
    #[test]
    fn test_package_name_parsing() -> Result<()> {
        assert_eq!(analyze("//:baz/qux")?.package_name, None);
        assert_eq!(analyze(":baz/qux")?.package_name, None);

        assert_eq!(analyze("//foo:baz/qux")?.package_name, Some("foo"));
        assert_eq!(analyze("//foo/bar:baz/qux")?.package_name, Some("foo/bar"));
        assert_eq!(
            analyze("foo:baz/qux"),
            Err(LabelError(
                "foo:baz/qux must be a legal label; relative packages are not permitted."
                    .to_string()
            ))
        );
        assert_eq!(
            analyze("foo/bar:baz/qux"),
            Err(LabelError(
                "foo/bar:baz/qux must be a legal label; relative packages are not permitted."
                    .to_string()
            ))
        );

        assert_eq!(analyze("//foo")?.package_name, Some("foo"));

        assert_eq!(
            analyze("foo//bar"),
            Err(LabelError(
                "foo//bar must be a legal label; '//' cannot appear in the middle of the label."
                    .to_string()
            ))
        );
        assert_eq!(
            analyze("//foo//bar"),
            Err(LabelError(
                "//foo//bar must be a legal label; '//' cannot appear in the middle of the label."
                    .to_string()
            ))
        );
        assert_eq!(
            analyze("foo//bar:baz"),
            Err(LabelError(
                "foo//bar:baz must be a legal label; '//' cannot appear in the middle of the label."
                    .to_string()
            ))
        );
        assert_eq!(
            analyze("//foo//bar:baz"),
            Err(LabelError(
                "//foo//bar:baz must be a legal label; '//' cannot appear in the middle of the label."
                    .to_string()
            ))
        );

        assert_eq!(
            analyze("//azAZ09/-. $()_:baz")?.package_name,
            Some("azAZ09/-. $()_")
        );
        assert_eq!(
            analyze("//bar#:baz"),
            Err(LabelError(
                "//bar#:baz must be a legal label; package names may contain only A-Z, \
                a-z, 0-9, '/', '-', '.', ' ', '$', '(', ')', '_', and '+'."
                    .to_string()
            ))
        );
        assert_eq!(
            analyze("//bar/:baz"),
            Err(LabelError(
                "//bar/:baz must be a legal label; package names may not end with '/'.".to_string()
            ))
        );

        assert_eq!(analyze("@repo//foo/bar")?.package_name, Some("foo/bar"));
        assert_eq!(analyze("//foo/bar")?.package_name, Some("foo/bar"));
        assert_eq!(
            analyze("foo/bar"),
            Err(LabelError(
                "foo/bar must be a legal label; relative packages are not permitted.".to_string()
            ))
        );

        assert_eq!(analyze("@repo//foo")?.package_name, Some("foo"));
        assert_eq!(analyze("//foo")?.package_name, Some("foo"));
        assert_eq!(
            analyze("foo"),
            Err(LabelError(
                "foo must be a legal label; relative packages are not permitted.".to_string()
            ))
        );

        Ok(())
    }

    #[test]
    fn test_name_parsing() -> Result<()> {
        assert_eq!(analyze("//foo:baz")?.name, "baz");
        assert_eq!(analyze("//foo:baz/qux")?.name, "baz/qux");

        assert_eq!(
            analyze("//bar:"),
            Err(LabelError(
                "//bar: must be a legal label; empty target name.".to_string()
            ))
        );
        assert_eq!(analyze("//foo")?.name, "foo");

        assert_eq!(
            analyze("//bar:/foo"),
            Err(LabelError(
                "//bar:/foo must be a legal label; target names may not start with '/'."
                    .to_string()
            ))
        );

        assert_eq!(analyze("@repo//foo/bar")?.name, "bar");
        assert_eq!(analyze("//foo/bar")?.name, "bar");
        assert_eq!(
            analyze("foo/bar"),
            Err(LabelError(
                "foo/bar must be a legal label; relative packages are not permitted.".to_string()
            ))
        );

        assert_eq!(analyze("@repo//foo")?.name, "foo");
        assert_eq!(analyze("//foo")?.name, "foo");
        assert_eq!(
            analyze("foo"),
            Err(LabelError(
                "foo must be a legal label; relative packages are not permitted.".to_string()
            ))
        );

        Ok(())
    }

    #[test]
    fn test_packages() -> Result<()> {
        assert_eq!(analyze("@repo//:baz")?.packages(), Vec::<&str>::new());
        assert_eq!(analyze("@repo//foo:baz")?.packages(), vec!["foo"]);
        assert_eq!(
            analyze("@repo//foo/bar:baz")?.packages(),
            vec!["foo", "bar"]
        );

        // Plus (+) is valid in packages
        assert_eq!(
            analyze("@repo//foo/bar+baz:qaz")?.packages(),
            vec!["foo", "bar+baz"]
        );

        Ok(())
    }
}
