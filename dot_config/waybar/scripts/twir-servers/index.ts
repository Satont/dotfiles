import { NodeSSH } from "node-ssh";

const SSH_PASSPHRASE = process.env.PASS;

interface Server {
  host: string;
  username: string;
  label: string;
  port?: number;
}

const SERVERS: Server[] = [
  { host: "5.78.89.245", username: "root", label: "Traefik" },
  { host: "5.78.66.221", username: "root", label: "Microservices 1" },
  { host: "5.78.45.190", username: "root", label: "Databases-1" },
];

// --- ICONS ---
const ICON_CPU = "󰻠";
const ICON_RAM = "󰍛";

// --- HELPER: GET STATS ---
async function getServerStats(server: Server) {
  const ssh = new NodeSSH();

  try {
    // We use 'exec' with sshpass to handle the password authentication.
    // This is necessary because node-ssh's internal connect()
    // does not easily support passing a password string directly for keyboard-interactive auth
    // without a key agent or keyboard interaction prompt.

    // Construct the command to run remotely
    // Using bash -c to ensure the whole block runs remotely
    const remoteCmd = `
            nproc_cores=$(nproc);
            read load_avg _ < /proc/loadavg;

            # Calculate CPU %: (Load / Cores) * 100
            cpu=$(awk "BEGIN {printf \\\"%.0f\\\", ($load_avg / $nproc_cores * 100)}");

            # Calculate RAM % using MemAvailable
            read total _ < <(grep MemTotal /proc/meminfo);
            read avail _ < <(grep MemAvailable /proc/meminfo);

            # Fallback for older kernels if MemAvailable is missing
            if [ -z "$avail" ]; then
                read free _ < <(grep MemFree /proc/meminfo);
                read buffers _ < <(grep Buffers /proc/meminfo);
                read cached _ < <(grep Cached /proc/meminfo);
                avail=$((free + buffers + cached));
            fi

            ram=$(awk "BEGIN {printf \\\"%.0f\\\", (($total - $avail) / $total * 100)}");

            echo "$cpu $ram"
        `;

    // Execute locally: sshpass -p 'pass' ssh user@host 'remote_command'
    // We use stdio: 'pipe' to capture the output cleanly.
    const result = await Bun.spawn(
      [
        "sshpass",
        "-p",
        SSH_PASSPHRASE,
        "ssh",
        `-o StrictHostKeyChecking=no`,
        `-o ConnectTimeout=2`,
        `-o UserKnownHostsFile=/dev/null`,
        `${server.username}@${server.host}`,
        remoteCmd,
      ],
      {
        stdout: "pipe",
        stderr: "pipe",
      },
    ).exited;

    // Note: Bun.spawn().exited returns a Promise<number>.
    // However, to get the output text, we need to capture the reader before .exited resolves
    // or restructure slightly. Let's restructure for safer output reading.

    return null; // Placeholder for the logic below
  } catch (error) {
    console.error(`Error connecting to ${server.label}:`, error);
    return null;
  }
}

// Rewritten Fetch Logic using Bun.spawn properly
async function fetchStats(
  server: Server,
): Promise<{ cpu: string; ram: string } | null> {
  const remoteCmd = `
        cores=$(nproc);
        read load _ < /proc/loadavg;
        cpu=$(awk "BEGIN {printf \\"%.0f\\", ($load / $cores * 100)}");

        total=$(grep MemTotal /proc/meminfo | awk '{print $2}');
        avail=$(grep MemAvailable /proc/meminfo | awk '{print $2}');

        if [ -z "$avail" ]; then
            free=$(grep MemFree /proc/meminfo | awk '{print $2}');
            buffers=$(grep Buffers /proc/meminfo | awk '{print $2}');
            cached=$(grep "^Cached:" /proc/meminfo | awk '{print $2}');
            avail=$((free + buffers + cached));
        fi

        ram=$(awk "BEGIN {printf \\"%.0f\\", (($total - $avail) / $total * 100)}");
        echo "$cpu $ram"
    `;

  const proc = Bun.spawn([
    "sshpass",
    "-p",
    SSH_PASSPHRASE,
    "ssh",
    "-o",
    "StrictHostKeyChecking=no",
    "-o",
    "ConnectTimeout=2",
    "-o",
    "UserKnownHostsFile=/dev/null",
    `${server.username}@${server.host}`,
    remoteCmd,
  ]);

  const exitCode = await proc.exited;

  if (exitCode !== 0) {
    return null;
  }

  const reader = proc.stdout.getReader();
  const { value } = await reader.read();
  const output = new TextDecoder().decode(value);

  if (!output.trim()) return null;

  const [cpu, ram] = output.trim().split(" ");
  return { cpu, ram };
}

// --- MAIN ---
async function main() {
  const results: Array<{
    text: string;
    class: string;
    tooltip: string;
    server: string;
  }> = [];

  await Promise.all(
    SERVERS.map(async (server) => {
      const stats = await fetchStats(server);

      if (stats) {
        results.push({
          text: `${server.label}: ${ICON_CPU} ${stats.cpu}% ${ICON_RAM} ${stats.ram}%`,
          class: `server-${server.label.toLowerCase().replace(/ /g, "-")}`,
          tooltip: `${server.username}@${server.host}`,
          server: server.label,
        });
      } else {
        results.push({
          text: `${server.label}: OFF`,
          class: "server-offline",
          tooltip: `${server.username}@${server.host} (Connection Failed)`,
          server: server.label,
        });
      }
    }),
  );

  // Format output for Waybar
  // Waybar expects an array of objects, or a single object.
  // To match the previous shell script behavior (multiple modules in one),
  // we join them with a separator or return a JSON array.

  // Let's return a JSON Array, Waybar handles this if return-type is json
  // But Waybar's 'custom' module usually expects a single object.
  // If you want 3 separate blocks, this logic needs to change.
  // Let's stick to the single JSON object with a pipe separator for consistency
  // with the previous shell script style.
  //

  const textOutput = results
    .sort((a, b) => a.server.localeCompare(b.server))
    .map((r) => r.text)
    .join(" | ");

  // We output a single JSON object representing the whole widget
  const finalOutput = {
    text: textOutput,
    class: "custom-servers",
    tooltip: "Server Monitor",
  };

  console.log(JSON.stringify(finalOutput));
}

main();
