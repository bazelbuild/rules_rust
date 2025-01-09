import path from "path";
import assert from "assert";
import { fileURLToPath } from "url";

const main = async function (typ, dir) {
    const filename = fileURLToPath(import.meta.url);
    const dirname = path.dirname(filename);

    const wasm_module = path.join(
        dirname,
        "..",
        dir,
        "test",
        `hello_world_${typ}_wasm_bindgen`,
        `hello_world_${typ}_wasm_bindgen.js`,
    );

    const res = await import(wasm_module);

    assert.strictEqual(res.instance.exports.double(2), 4);
};

["bundler", "web", "deno", "nomodules", "nodejs"].forEach((typ) => {
    main(typ, process.argv.length > 2 ? process.argv[2] : "").catch((err) => {
        console.error(err);
        process.exit(1);
    });
});
