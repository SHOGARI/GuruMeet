export type DiscordAlertLevel = "info" | "warning" | "critical";

type DiscordAlertFieldValue = string | number | boolean | null | undefined;

interface DiscordAlertOptions {
  webhookUrl?: string;
  title: string;
  level?: DiscordAlertLevel;
  fields: Record<string, DiscordAlertFieldValue>;
}

const DISCORD_COLORS: Record<DiscordAlertLevel, number> = {
  info: 0x2563eb,
  warning: 0xf59e0b,
  critical: 0xdc2626,
};

export async function sendDiscordAlert({
  webhookUrl,
  title,
  level = "info",
  fields,
}: DiscordAlertOptions): Promise<void> {
  const normalizedWebhookUrl = webhookUrl?.trim();
  if (!normalizedWebhookUrl) {
    return;
  }

  const response = await fetch(normalizedWebhookUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      allowed_mentions: { parse: [] },
      embeds: [
        {
          title,
          color: DISCORD_COLORS[level],
          fields: Object.entries(fields).map(([name, value]) => ({
            name,
            value: fieldValue(value),
            inline: true,
          })),
        },
      ],
    }),
  });

  if (!response.ok) {
    throw new Error(`Discord webhook failed with status ${response.status}`);
  }
}

function fieldValue(value: DiscordAlertFieldValue): string {
  if (value === null || value === undefined || value === "") {
    return "(none)";
  }
  if (typeof value === "boolean") {
    return value ? "true" : "false";
  }
  const text = String(value);
  if (text.length > 1024) {
    return `${text.slice(0, 1021)}...`;
  }
  return text;
}
