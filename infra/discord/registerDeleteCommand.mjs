const DISCORD_API_BASE_URL = "https://discord.com/api/v10";
const MANAGE_GUILD_PERMISSION = "32";

const applicationId = requiredEnv("DISCORD_APPLICATION_ID");
const botToken = requiredEnv("DISCORD_BOT_TOKEN");
const guildId = process.env.DISCORD_GUILD_ID?.trim();

const command = {
  name: "delete",
  type: 1,
  description: "Run GuruMeet cleanup manually.",
  default_member_permissions: MANAGE_GUILD_PERMISSION,
  dm_permission: false,
  integration_types: [0],
  contexts: [0],
  options: [
    {
      name: "staging",
      type: 1,
      description: "Delete expired temporary data in staging.",
    },
    {
      name: "production",
      type: 1,
      description: "Delete expired temporary data in production.",
    },
  ],
};

const endpoint = guildId
  ? `${DISCORD_API_BASE_URL}/applications/${applicationId}/guilds/${guildId}/commands`
  : `${DISCORD_API_BASE_URL}/applications/${applicationId}/commands`;

const existingCommandsResponse = await discordFetch(endpoint);
const existingCommands = await existingCommandsResponse.json();
if (!Array.isArray(existingCommands)) {
  throw new Error("Discord commands response must be an array.");
}

const existingDeleteCommand = existingCommands.find(
  (existingCommand) =>
    existingCommand &&
    typeof existingCommand === "object" &&
    existingCommand.name === "delete" &&
    typeof existingCommand.id === "string",
);

const response = await discordFetch(
  existingDeleteCommand
    ? `${endpoint}/${existingDeleteCommand.id}`
    : endpoint,
  {
    method: existingDeleteCommand ? "PATCH" : "POST",
    body: JSON.stringify(command),
  },
);

await response.json();

console.log(
  `${existingDeleteCommand ? "Updated" : "Registered"} /delete command for ${
    guildId ? `guild ${guildId}` : "global commands"
  }.`,
);

async function discordFetch(url, init = {}) {
  const response = await fetch(url, {
    method: init.method ?? "GET",
    headers: {
      Authorization: `Bot ${botToken}`,
      "Content-Type": "application/json",
      ...init.headers,
    },
    body: init.body,
  });
  if (!response.ok) {
    const responseBody = await response.text();
    throw new Error(
      `Discord API request failed: status=${response.status}, body=${responseBody}`,
    );
  }
  return response;
}

function requiredEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`${name} must be configured.`);
  }
  return value;
}
