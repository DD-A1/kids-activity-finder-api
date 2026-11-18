import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { db } from "../db/client.js";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));

const referenceDataDirectory = path.resolve(
  scriptDirectory,
  "../db/reference_data",
);

const placeFile = path.join(
  referenceDataDirectory,
  "2026_Gaz_place_national.txt",
);

const LSAD_TYPES = {
  "00": "BALANCE",
  21: "BOROUGH",
  25: "CITY",
  37: "MUNICIPALITY",
  43: "TOWN",
  47: "VILLAGE",
  53: "CITY_BOROUGH",
  55: "COMUNIDAD",
  57: "CDP",
  62: "URBAN_ZONE",
  CG: "SPECIAL_GOVERNMENT",
  CN: "SPECIAL_GOVERNMENT",
  MG: "SPECIAL_GOVERNMENT",
  UC: "SPECIAL_GOVERNMENT",
  UG: "SPECIAL_GOVERNMENT",
};

const VALID_FUNCTIONAL_STATUSES = new Set(["A", "B", "F", "I", "N", "S"]);

// Read the pipe-delimited Census file.
async function readCensusFile(filePath) {
  const contents = await fs.readFile(filePath, "utf8");

  const lines = contents
    .replace(/^\uFEFF/, "")
    .split(/\r?\n/)
    .filter((line) => line.trim() !== "");

  const headers = lines[0].split("|").map((value) => value.trim());

  return lines.slice(1).map((line, index) => {
    const values = line.split("|");

    if (values.length !== headers.length) {
      throw new Error(`Invalid column count on Census file line ${index + 2}`);
    }

    return Object.fromEntries(
      headers.map((header, columnIndex) => [
        header,
        values[columnIndex].trim(),
      ]),
    );
  });
}

// Remove Census designation suffixes for cleaner app display.
// The complete original name is preserved in census_name.
function getDisplayName(censusName, lsadCode) {
  const suffixes = {
    21: /\s+borough$/i,
    25: /\s+city$/i,
    37: /\s+municipality$/i,
    43: /\s+town$/i,
    47: /\s+village$/i,
    53: /\s+city and borough$/i,
    55: /\s+comunidad$/i,
    57: /\s+CDP$/i,
    62: /\s+zona urbana$/i,
    "00": /\s+\(balance\)$/i,
  };

  return censusName.replace(suffixes[lsadCode] ?? /$^/, "").trim();
}

function preparePlaces(records, stateIds) {
  const prepared = records.map((record) => {
    const cityType = LSAD_TYPES[record.LSAD];

    if (!cityType) {
      throw new Error(
        `Unsupported LSAD code ${record.LSAD} for ${record.NAME}`,
      );
    }

    if (!VALID_FUNCTIONAL_STATUSES.has(record.FUNCSTAT)) {
      throw new Error(
        `Invalid functional status ${record.FUNCSTAT} for ${record.NAME}`,
      );
    }

    const stateId = stateIds.get(record.USPS);

    if (!stateId) {
      throw new Error(
        `No database state found for ${record.USPS}: ${record.NAME}`,
      );
    }

    const latitude = Number(record.INTPTLAT);
    const longitude = Number(record.INTPTLONG);

    if (
      !Number.isFinite(latitude) ||
      !Number.isFinite(longitude) ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180
    ) {
      throw new Error(`Invalid coordinates for ${record.NAME}`);
    }

    return {
      stateId,
      cityName: getDisplayName(record.NAME, record.LSAD),
      cityType,
      geoid: record.GEOID,
      censusName: record.NAME,
      lsadCode: record.LSAD,
      funcstat: record.FUNCSTAT,
      latitude,
      longitude,
    };
  });

  // Detect duplicate normalized names and types within a state.
  // If a collision exists, restore the original Census name
  // for every record in that duplicate group.
  const nameGroups = new Map();

  for (const place of prepared) {
    const key = [
      place.stateId,
      place.cityName.trim().toLowerCase(),
      place.cityType,
    ].join("|");

    if (!nameGroups.has(key)) {
      nameGroups.set(key, []);
    }

    nameGroups.get(key).push(place);
  }

  for (const group of nameGroups.values()) {
    if (group.length > 1) {
      for (const place of group) {
        place.cityName = place.censusName;
      }
    }
  }

  // Final safety check against the database's unique name/type index.
  for (const group of nameGroups.values()) {
    if (group.length > 1) {
      for (const place of group) {
        place.cityName = place.censusName;
      }
    }
  }

  return prepared;
}

async function importPlaces() {
  let client;

  try {
    console.log("Reading Census place reference file...");

    const records = await readCensusFile(placeFile);

    console.log(`Found ${records.length} Census place records.`);

    client = await db.connect();

    await client.query("BEGIN");

    console.log("Loading state identifiers...");

    const stateResult = await client.query(`
      SELECT id, state_code
      FROM geography.states
      WHERE country_code = 'US';
    `);

    const stateIds = new Map(
      stateResult.rows.map((state) => [state.state_code, state.id]),
    );

    if (stateIds.size !== 52) {
      throw new Error(
        `Expected 52 US state-level jurisdictions; found ${stateIds.size}.`,
      );
    }

    const places = preparePlaces(records, stateIds);

    console.log("Source data validation passed.");
    console.log("Importing places in batches...");

    const batchSize = 500;
    let importedCount = 0;

    for (let start = 0; start < places.length; start += batchSize) {
      const batch = places.slice(start, start + batchSize);
      const values = [];
      const placeholders = [];

      for (let index = 0; index < batch.length; index++) {
        const place = batch[index];
        const offset = index * 9;

        placeholders.push(
          `($${offset + 1}, $${offset + 2}, $${offset + 3},
            $${offset + 4}, $${offset + 5}, $${offset + 6},
            $${offset + 7}, $${offset + 8}, $${offset + 9})`,
        );

        values.push(
          place.stateId,
          place.cityName,
          place.cityType,
          place.geoid,
          place.censusName,
          place.lsadCode,
          place.funcstat,
          place.latitude,
          place.longitude,
        );
      }

      await client.query(
        `
          INSERT INTO geography.cities (
            state_id,
            city_name,
            city_type,
            geoid,
            census_name,
            census_lsad_code,
            census_funcstat,
            latitude,
            longitude
          )
          VALUES ${placeholders.join(", ")}
          ON CONFLICT (geoid)
          WHERE geoid IS NOT NULL
          DO UPDATE SET
            state_id = EXCLUDED.state_id,
            city_name = EXCLUDED.city_name,
            city_type = EXCLUDED.city_type,
            census_name = EXCLUDED.census_name,
            census_lsad_code = EXCLUDED.census_lsad_code,
            census_funcstat = EXCLUDED.census_funcstat,
            latitude = EXCLUDED.latitude,
            longitude = EXCLUDED.longitude;
        `,
        values,
      );

      importedCount += batch.length;

      console.log(`Processed ${importedCount} of ${places.length} places.`);
    }

    await client.query("COMMIT");

    console.log("");
    console.log("========== PLACE IMPORT COMPLETE ==========");
    console.log(`Places imported or updated: ${importedCount}`);
    console.log("Database transaction committed successfully.");
  } catch (error) {
    if (client) {
      await client.query("ROLLBACK");
    }

    console.error("");
    console.error("PLACE IMPORT FAILED");
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

await importPlaces();
