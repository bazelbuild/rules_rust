//! Tests the Google well-known types.

use any_proto::google::protobuf::Any;
use api_proto::google::protobuf::{Api, Method, Mixin};
use compiler_plugin_proto::google::protobuf::compiler::Version;
use descriptor_proto::google::protobuf::DescriptorProto;
use duration_proto::google::protobuf::Duration;
use empty_proto::google::protobuf::Empty;
use field_mask_proto::google::protobuf::FieldMask;
use source_context_proto::google::protobuf::SourceContext;
use struct_proto::google::protobuf::Struct;
use struct_proto::google::protobuf::Value;
use timestamp_proto::google::protobuf::Timestamp;
use type_proto::google::protobuf::field::{Cardinality, Kind};
use type_proto::google::protobuf::{Field, Option, Syntax, Type};
use well_known_types_proto::wkt::WellKnownTypes;
use wrappers_proto::google::protobuf::{
    BoolValue, BytesValue, DoubleValue, FloatValue, Int32Value, Int64Value, StringValue,
    UInt32Value, UInt64Value,
};

#[test]
fn test_well_known_types() {
    let wkt = WellKnownTypes {
        any: Some(Any {
            type_url: "type.googleapis.com/google.protobuf.Any".to_string(),
            value: vec![],
        }),
        api: Some(Api {
            name: "api".to_string(),
            methods: vec![Method {
                name: "method".to_string(),
                ..Method::default()
            }],
            options: vec![Option {
                name: "option".to_string(),
                ..Option::default()
            }],
            version: "1.2.3".to_string(),
            source_context: Some(SourceContext {
                file_name: "file_name".to_string(),
            }),
            mixins: vec![Mixin {
                name: "mixin".to_string(),
                ..Mixin::default()
            }],
            syntax: Syntax::Proto3.into(),
        }),
        method: Some(Method {
            name: "method".to_string(),
            ..Method::default()
        }),
        mixin: Some(Mixin {
            name: "mixin".to_string(),
            ..Mixin::default()
        }),
        compiler_version: Some(Version {
            major: Some(1),
            minor: Some(2),
            patch: Some(3),
            suffix: Some("suffix".to_string()),
        }),
        descriptor_proto: Some(DescriptorProto::default()),
        empty: Some(Empty::default()),
        duration: Some(Duration {
            seconds: 1,
            nanos: 2,
        }),
        field_mask: Some(FieldMask {
            paths: vec!["path".to_string()],
        }),
        source_context: Some(SourceContext {
            file_name: "file_name".to_string(),
        }),
        r#struct: Some(Struct {
            fields: vec![("field".to_string(), Value::default())]
                .into_iter()
                .collect(),
        }),
        timestamp: Some(Timestamp {
            seconds: 1,
            nanos: 2,
        }),
        r#type: Some(Type {
            name: "type".to_string(),
            fields: vec![Field {
                kind: Kind::TypeDouble.into(),
                cardinality: Cardinality::Required.into(),
                ..Field::default()
            }],
            ..Type::default()
        }),
        bool_value: Some(BoolValue { value: true }),
        bytes_value: Some(BytesValue { value: vec![] }),
        double_value: Some(DoubleValue { value: 1.0 }),
        float_value: Some(FloatValue { value: 1.1 }),
        int32_value: Some(Int32Value { value: 2 }),
        int64_value: Some(Int64Value { value: 3 }),
        string_value: Some(StringValue {
            value: "value".to_string(),
        }),
        uint32_value: Some(UInt32Value { value: 4 }),
        uint64_value: Some(UInt64Value { value: 5 }),
    };

    assert!(wkt.any.is_some());
}
