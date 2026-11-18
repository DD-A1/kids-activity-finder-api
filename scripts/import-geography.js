import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { db } from "../db/client.js";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));

const referenceDataDirectory = path.resolve(
  scriptDirectory,
  "../db/reference_data",
);

const stateFile = path.join(
  referenceDataDirectory,
  "2026_Gaz_state_national.txt",
);

const countyFile = path.join(
  referenceDataDirectory,
  "2026_Gaz_counties_national.txt",
);

// Read a pipe-delimited Census file and convert it
// into an array of objects using its header row.
async function readCensusFile(filePath) {
  const fileContents = await fs.readFile(filePath, "utf8");

  const lines = fileContents
    .replace(/^\uFEFF/, "")
    .split(/\r?\n/)
    .filter((line) => line.trim() !== "");

  if (lines.length < 2) {
    throw new Error(`No data records found in ${filePath}`);
  }

  const headers = lines[0].split("|").map((header) => header.trim());

  return lines.slice(1).map((line, index) => {
    const values = line.split("|");

    if (values.length !== headers.length) {
      throw new Error(
        `Invalid column count in ${path.basename(filePath)}, line ${index + 2}`,
      );
    }

    return Object.fromEntries(
      headers.map((header, columnIndex) => [
        header,
        values[columnIndex].trim(),
      ]),
    );
  });
}

// Validate the Census source records before touching the database.
function validateSourceData(states, counties) {
  const stateCodes = new Set();

  for (const state of states) {
    if (!state.USPS || !state.NAME || !state.GEOID) {
      throw new Error("A state record is missing required information.");
    }

    if (stateCodes.has(state.USPS)) {
      throw new Error(`Duplicate state code: ${state.USPS}`);
    }

    stateCodes.add(state.USPS);
  }

  const countyGeoids = new Set();

  for (const county of counties) {
    if (!county.USPS || !county.GEOID || !county.NAME) {
      throw new Error("A county record is missing required information.");
    }

    if (countyGeoids.has(county.GEOID)) {
      throw new Error(`Duplicate county GEOID: ${county.GEOID}`);
    }

    if (!stateCodes.has(county.USPS)) {
      throw new Error(
        `County ${county.NAME} references unknown state ${county.USPS}`,
      );
    }

    countyGeoids.add(county.GEOID);
  }
}

async function importGeography() {
  let client;

  try {
    console.log("Reading Census reference files...");

    const states = await readCensusFile(stateFile);
    const counties = await readCensusFile(countyFile);

    console.log(`Found ${states.length} state records.`);
    console.log(`Found ${counties.length} county records.`);

    validateSourceData(states, counties);

    console.log("Source data validation passed.");
    console.log("Connecting to PostgreSQL...");

    client = await db.connect();

    await client.query("BEGIN");

    // Keep track of database state IDs so each county
    // can be connected to its correct state.
    const stateIds = new Map();

    console.log("Importing states...");

    for (const state of states) {
      const result = await client.query(
        `
          INSERT INTO geography.states (
            country_code,
            state_code,
            state_name
          )
          VALUES ($1, $2, $3)
          ON CONFLICT (country_code, state_code)
          DO UPDATE SET
            state_name = EXCLUDED.state_name
          RETURNING id, state_code;
        `,
        ["US", state.USPS, state.NAME],
      );

      stateIds.set(result.rows[0].state_code, result.rows[0].id);
    }

    console.log(`Imported or updated ${stateIds.size} states.`);

    console.log("Importing counties...");

    let countyCount = 0;

    for (const county of counties) {
      const stateId = stateIds.get(county.USPS);

      if (!stateId) {
        throw new Error(
          `Could not find database state for county ${county.NAME}`,
        );
      }

      await client.query(
        `
          INSERT INTO geography.counties (
            state_id,
            county_name,
            geoid
          )
          VALUES ($1, $2, $3)
          ON CONFLICT (geoid)
          DO UPDATE SET
            state_id = EXCLUDED.state_id,
            county_name = EXCLUDED.county_name;
        `,
        [stateId, county.NAME, county.GEOID],
      );

      countyCount++;
    }

    await client.query("COMMIT");

    console.log("");
    console.log("========== IMPORT COMPLETE ==========");
    console.log(`States imported or updated: ${stateIds.size}`);
    console.log(`Counties imported or updated: ${countyCount}`);
    console.log("Database transaction committed successfully.");
  } catch (error) {
    if (client) {
      await client.query("ROLLBACK");
    }

    console.error("");
    console.error("GEOGRAPHY IMPORT FAILED");
    console.error(error.message);
    console.error("Database transaction rolled back.");

    process.exitCode = 1;
  } finally {
    if (client) {
      client.release();
    }

    await db.end();
  }
}

await importGeography();
