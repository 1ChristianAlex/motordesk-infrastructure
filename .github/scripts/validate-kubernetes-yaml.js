import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

const root = path.resolve("infra/kubernetes");

async function findYamlFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nestedFiles = await Promise.all(
    entries.map(async (entry) => {
      const entryPath = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        return findYamlFiles(entryPath);
      }

      return entry.isFile() &&
        (entry.name.endsWith(".yaml") || entry.name.endsWith(".yaml.tpl"))
        ? [entryPath]
        : [];
    }),
  );

  return nestedFiles.flat();
}

const files = (await findYamlFiles(root)).sort();
if (files.length === 0) {
  throw new Error(`No Kubernetes YAML files found under ${root}`);
}

for (const file of files) {
  const parsed = Bun.YAML.parse(await readFile(file, "utf8"));
  const documents = Array.isArray(parsed) ? parsed : [parsed];
  if (
    documents.length === 0 ||
    documents.some(
      (document) =>
        document === null ||
        typeof document !== "object" ||
        Array.isArray(document),
    )
  ) {
    throw new Error(`${file}: expected one or more Kubernetes YAML objects`);
  }

  console.log(`validated ${path.relative(process.cwd(), file)}`);
}
