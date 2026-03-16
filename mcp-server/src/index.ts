#!/usr/bin/env node
/**
 * Pacelli MCP Server
 *
 * Exposes the Pacelli household management API as MCP tools,
 * allowing AI assistants (Claude, ChatGPT, Gemini) to manage
 * tasks, inventory, checklists, plans, and more.
 *
 * Transport modes:
 *   --stdio     (default) Local stdio transport for Claude Desktop
 *   --http      Streamable HTTP transport for hosted/remote access
 *
 * Configuration via environment variables:
 *   PACELLI_API_URL            — Cloud Functions base URL
 *   GOOGLE_APPLICATION_CREDENTIALS — Path to service account key (local dev)
 *   FIREBASE_API_KEY           — Firebase web API key
 *   MCP_SERVICE_USER_UID       — Firebase UID of the service user to impersonate
 *   PORT                       — HTTP server port (default: 3000, --http mode only)
 *   MCP_ALLOWED_ORIGINS        — Comma-separated allowed origins (--http mode)
 */
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { z } from "zod";
import { createServer, IncomingMessage, ServerResponse } from "node:http";
import { ApiClient } from "./api-client.js";
import { tokenManager } from "./token-manager.js";

// ── Configuration ──

const API_URL = process.env.PACELLI_API_URL;

if (!API_URL) {
  console.error("Missing required environment variable: PACELLI_API_URL");
  process.exit(1);
}

const isHttpMode = process.argv.includes("--http");

// Enforce HTTPS for API URL in HTTP (production) mode
if (isHttpMode && !API_URL.startsWith("https://")) {
  console.error("PACELLI_API_URL must use https:// in HTTP mode");
  process.exit(1);
}

const api = new ApiClient({
  baseUrl: API_URL,
  tokenProvider: () => tokenManager.getValidToken(),
});

// ── Server (stdio mode uses this single instance) ──

const server = new McpServer({
  name: "pacelli",
  version: "1.0.0",
});

/**
 * Register all tools and resources on the given McpServer instance.
 * Called once for the stdio server, and once per HTTP session.
 */
function registerToolsAndResources(s: McpServer) {
  _registerTools(s);
  _registerResources(s);
}

// Wire up the main (stdio) server instance
registerToolsAndResources(server);

// ── Tool & Resource Registration ────────────────────────────────

function _registerTools(server: McpServer) {
// ═══════════════════════════════════════════════════════════════════
//  TASK TOOLS
// ═══════════════════════════════════════════════════════════════════

server.registerTool(
  "list_tasks",
  {
    description:
      "List tasks for the household. Optionally filter by status, category, priority, or assignee.",
    inputSchema: {
      status: z
        .enum(["pending", "in_progress", "completed"])
        .optional()
        .describe("Filter by task status"),
      categoryId: z.string().optional().describe("Filter by category ID"),
      priority: z
        .enum(["low", "medium", "high", "urgent"])
        .optional()
        .describe("Filter by priority"),
      assignedTo: z.string().optional().describe("Filter by assignee user ID"),
      isShared: z.boolean().optional().describe("Filter by shared status"),
    },
  },
  async (params) => {
    const data = await api.call("tasksList", params);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.registerTool(
  "get_task",
  {
    description:
      "Get a single task by ID, including its subtasks and category.",
    inputSchema: {
      taskId: z.string().describe("The task ID"),
    },
  },
  async ({ taskId }) => {
    const data = await api.call("tasksGet", { taskId });
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.registerTool(
  "create_task",
  {
    description:
      "Create a new task in the household. Returns the created task.",
    inputSchema: {
      title: z.string().describe("Task title"),
      description: z.string().optional().describe("Task description"),
      categoryId: z.string().optional().describe("Category ID"),
      priority: z
        .enum(["low", "medium", "high", "urgent"])
        .optional()
        .describe("Priority level (default: medium)"),
      dueDate: z
        .string()
        .optional()
        .describe("Due date in ISO 8601 format"),
      startDate: z
        .string()
        .optional()
        .describe("Start date in ISO 8601 format"),
      assignedTo: z
        .string()
        .optional()
        .describe("User ID to assign the task to"),
      isShared: z
        .boolean()
        .optional()
        .describe("Whether the task is shared with the household"),
      recurrence: z
        .enum(["none", "daily", "weekly", "monthly"])
        .optional()
        .describe("Recurrence pattern"),
      subtaskTitles: z
        .array(z.string())
        .optional()
        .describe("List of subtask titles to create"),
    },
  },
  async (params) => {
    const data = await api.call("tasksCreate", params);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.registerTool(
  "update_task",
  {
    description:
      "Update an existing task. Only provide fields you want to change.",
    inputSchema: {
      taskId: z.string().describe("The task ID to update"),
      title: z.string().optional().describe("New title"),
      description: z.string().optional().describe("New description"),
      categoryId: z.string().optional().describe("New category ID"),
      priority: z
        .enum(["low", "medium", "high", "urgent"])
        .optional()
        .describe("New priority"),
      status: z
        .enum(["pending", "in_progress", "completed"])
        .optional()
        .describe("New status"),
      dueDate: z.string().optional().describe("New due date (ISO 8601)"),
      startDate: z.string().optional().describe("New start date (ISO 8601)"),
      assignedTo: z
        .string()
        .optional()
        .describe("User ID to reassign to"),
      isShared: z.boolean().optional().describe("Toggle shared status"),
      recurrence: z
        .enum(["none", "daily", "weekly", "monthly"])
        .optional()
        .describe("New recurrence pattern"),
    },
  },
  async (params) => {
    const data = await api.call("tasksUpdate", params);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.registerTool(
  "complete_task",
  {
    description: "Mark a task as completed.",
    inputSchema: {
      taskId: z.string().describe("The task ID to complete"),
    },
  },
  async ({ taskId }) => {
    await api.call("tasksComplete", { taskId });
    return { content: [{ type: "text", text: `Task ${taskId} completed.` }] };
  }
);

server.registerTool(
  "delete_task",
  {
    description:
      "Delete a task and all its subtasks. This is irreversible.",
    inputSchema: {
      taskId: z.string().describe("The task ID to delete"),
    },
  },
  async ({ taskId }) => {
    await api.call("tasksDelete", { taskId });
    return { content: [{ type: "text", text: `Task ${taskId} deleted.` }] };
  }
);

server.registerTool(
  "manage_subtask",
  {
    description:
      "Add, toggle, or delete a subtask. Specify the action to perform.",
    inputSchema: {
      action: z
        .enum(["add", "toggle", "delete"])
        .describe("Action to perform on the subtask"),
      taskId: z
        .string()
        .optional()
        .describe("Parent task ID (required for 'add')"),
      subtaskId: z
        .string()
        .optional()
        .describe("Subtask ID (required for 'toggle' and 'delete')"),
      title: z
        .string()
        .optional()
        .describe("Subtask title (required for 'add')"),
      isCompleted: z
        .boolean()
        .optional()
        .describe("Completion state (required for 'toggle')"),
    },
  },
  async (params) => {
    switch (params.action) {
      case "add": {
        const data = await api.call("subtasksAdd", {
          taskId: params.taskId,
          title: params.title,
        });
        return {
          content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
        };
      }
      case "toggle": {
        await api.call("subtasksToggle", {
          subtaskId: params.subtaskId,
          isCompleted: params.isCompleted,
        });
        return {
          content: [{ type: "text", text: `Subtask toggled.` }],
        };
      }
      case "delete": {
        await api.call("subtasksDelete", {
          subtaskId: params.subtaskId,
        });
        return {
          content: [{ type: "text", text: `Subtask deleted.` }],
        };
      }
    }
  }
);

server.registerTool(
  "get_task_stats",
  {
    description:
      "Get task statistics: completed, pending, overdue, total, and completion rate.",
    inputSchema: {},
  },
  async () => {
    const data = await api.call("tasksStats");
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

// ═══════════════════════════════════════════════════════════════════
//  CATEGORY TOOLS
// ═══════════════════════════════════════════════════════════════════

server.registerTool(
  "manage_categories",
  {
    description:
      "List, create, or delete task categories.",
    inputSchema: {
      action: z
        .enum(["list", "create", "delete"])
        .describe("Action to perform"),
      name: z
        .string()
        .optional()
        .describe("Category name (required for 'create')"),
      icon: z.string().optional().describe("Material icon name"),
      color: z.string().optional().describe("Hex colour (e.g. #7EA87E)"),
      categoryId: z
        .string()
        .optional()
        .describe("Category ID (required for 'delete')"),
    },
  },
  async (params) => {
    switch (params.action) {
      case "list": {
        const data = await api.call("categoriesList");
        return {
          content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
        };
      }
      case "create": {
        const data = await api.call("categoriesCreate", {
          name: params.name,
          icon: params.icon,
          color: params.color,
        });
        return {
          content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
        };
      }
      case "delete": {
        await api.call("categoriesDelete", {
          categoryId: params.categoryId,
        });
        return {
          content: [{ type: "text", text: `Category deleted.` }],
        };
      }
    }
  }
);

// ═══════════════════════════════════════════════════════════════════
//  CHECKLIST TOOLS
// ═══════════════════════════════════════════════════════════════════

server.registerTool(
  "list_checklists",
  {
    description:
      "List all standalone checklists with their items.",
    inputSchema: {},
  },
  async () => {
    const data = await api.call("checklistsList");
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.registerTool(
  "create_checklist",
  {
    description: "Create a new standalone checklist.",
    inputSchema: {
      title: z.string().describe("Checklist title"),
    },
  },
  async ({ title }) => {
    const data = await api.call("checklistsCreate", { title });
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.registerTool(
  "manage_checklist",
  {
    description:
      "Update title, delete a checklist, or manage its items (add, toggle, delete, push-as-task).",
    inputSchema: {
      action: z
        .enum([
          "update_title",
          "delete",
          "add_item",
          "toggle_item",
          "delete_item",
          "push_item_as_task",
        ])
        .describe("Action to perform"),
      checklistId: z
        .string()
        .optional()
        .describe("Checklist ID (required for update_title, delete, add_item)"),
      title: z
        .string()
        .optional()
        .describe("New title (for update_title) or item title (for add_item)"),
      quantity: z
        .string()
        .optional()
        .describe("Item quantity (for add_item)"),
      itemId: z
        .string()
        .optional()
        .describe("Item ID (for toggle/delete/push actions)"),
      isChecked: z
        .boolean()
        .optional()
        .describe("Checked state (for toggle_item)"),
      itemTitle: z
        .string()
        .optional()
        .describe("Item title (for push_item_as_task)"),
    },
  },
  async (params) => {
    switch (params.action) {
      case "update_title": {
        const data = await api.call("checklistsUpdate", {
          checklistId: params.checklistId,
          title: params.title,
        });
        return {
          content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
        };
      }
      case "delete": {
        await api.call("checklistsDelete", {
          checklistId: params.checklistId,
        });
        return { content: [{ type: "text", text: "Checklist deleted." }] };
      }
      case "add_item": {
        const data = await api.call("checklistItemsAdd", {
          checklistId: params.checklistId,
          title: params.title,
          quantity: params.quantity,
        });
        return {
          content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
        };
      }
      case "toggle_item": {
        await api.call("checklistItemsToggle", {
          itemId: params.itemId,
          isChecked: params.isChecked,
        });
        return { content: [{ type: "text", text: "Item toggled." }] };
      }
      case "delete_item": {
        await api.call("checklistItemsDelete", { itemId: params.itemId });
        return { content: [{ type: "text", text: "Item deleted." }] };
      }
      case "push_item_as_task": {
        await api.call("checklistItemsPushAsTask", {
          itemId: params.itemId,
          itemTitle: params.itemTitle,
        });
        return {
          content: [{ type: "text", text: "Item pushed as task." }],
        };
      }
    }
  }
);

// ═══════════════════════════════════════════════════════════════════
//  PLAN TOOLS
// ═══════════════════════════════════════════════════════════════════

server.registerTool(
  "list_plans",
  {
    description:
      "List all plans (non-templates) with their entries and checklist items.",
    inputSchema: {},
  },
  async () => {
    const data = await api.call("plansList");
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.registerTool(
  "get_plan",
  {
    description:
      "Get a single plan with all entries and checklist items.",
    inputSchema: {
      planId: z.string().describe("The plan ID"),
    },
  },
  async ({ planId }) => {
    const data = await api.call("plansGet", { planId });
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.registerTool(
  "create_plan",
  {
    description:
      "Create a new plan (weekly, daily, or custom) with a date range.",
    inputSchema: {
      title: z.string().describe("Plan title"),
      type: z
        .enum(["weekly", "daily", "custom"])
        .optional()
        .describe("Plan type (default: weekly)"),
      startDate: z.string().describe("Start date (YYYY-MM-DD)"),
      endDate: z.string().describe("End date (YYYY-MM-DD)"),
    },
  },
  async (params) => {
    const data = await api.call("plansCreate", params);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.registerTool(
  "manage_plan",
  {
    description:
      "Delete a plan, update its status, finalise it (push entries as tasks), or manage entries and checklist items.",
    inputSchema: {
      action: z
        .enum([
          "delete",
          "update_status",
          "finalise",
          "add_entry",
          "update_entry",
          "delete_entry",
          "add_checklist_item",
          "toggle_checklist_item",
          "delete_checklist_item",
        ])
        .describe("Action to perform"),
      planId: z
        .string()
        .optional()
        .describe("Plan ID (required for most actions)"),
      status: z
        .string()
        .optional()
        .describe("New status (for update_status)"),
      entryActions: z
        .record(z.string())
        .optional()
        .describe(
          "Map of entry ID → action ('task', 'note', 'skip') for finalise"
        ),
      // Entry fields
      entryId: z.string().optional().describe("Entry ID"),
      entryDate: z.string().optional().describe("Entry date (YYYY-MM-DD)"),
      title: z.string().optional().describe("Title (for entries and items)"),
      label: z.string().optional().describe("Label (for entries)"),
      description: z.string().optional().describe("Description (for entries)"),
      sortOrder: z.number().optional().describe("Sort order (for entries)"),
      // Checklist item fields
      itemId: z.string().optional().describe("Checklist item ID"),
      quantity: z.string().optional().describe("Quantity (for items)"),
      isChecked: z.boolean().optional().describe("Checked state"),
    },
  },
  async (params) => {
    switch (params.action) {
      case "delete": {
        await api.call("plansDelete", { planId: params.planId });
        return { content: [{ type: "text", text: "Plan deleted." }] };
      }
      case "update_status": {
        await api.call("plansUpdateStatus", {
          planId: params.planId,
          status: params.status,
        });
        return {
          content: [{ type: "text", text: `Plan status updated to ${params.status}.` }],
        };
      }
      case "finalise": {
        await api.call("plansFinalise", {
          planId: params.planId,
          entryActions: params.entryActions,
        });
        return { content: [{ type: "text", text: "Plan finalised." }] };
      }
      case "add_entry": {
        const data = await api.call("planEntriesAdd", {
          planId: params.planId,
          entryDate: params.entryDate,
          title: params.title,
          label: params.label,
          description: params.description,
          sortOrder: params.sortOrder,
        });
        return {
          content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
        };
      }
      case "update_entry": {
        await api.call("planEntriesUpdate", {
          entryId: params.entryId,
          title: params.title,
          label: params.label,
          description: params.description,
        });
        return { content: [{ type: "text", text: "Entry updated." }] };
      }
      case "delete_entry": {
        await api.call("planEntriesDelete", { entryId: params.entryId });
        return { content: [{ type: "text", text: "Entry deleted." }] };
      }
      case "add_checklist_item": {
        const data = await api.call("planChecklistItemsAdd", {
          planId: params.planId,
          entryId: params.entryId,
          title: params.title,
          quantity: params.quantity,
        });
        return {
          content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
        };
      }
      case "toggle_checklist_item": {
        await api.call("planChecklistItemsToggle", {
          itemId: params.itemId,
          isChecked: params.isChecked,
        });
        return { content: [{ type: "text", text: "Checklist item toggled." }] };
      }
      case "delete_checklist_item": {
        await api.call("planChecklistItemsDelete", { itemId: params.itemId });
        return {
          content: [{ type: "text", text: "Checklist item deleted." }],
        };
      }
    }
  }
);

server.registerTool(
  "manage_templates",
  {
    description:
      "List plan templates, save a plan as a template, or create a new plan from a template.",
    inputSchema: {
      action: z
        .enum(["list", "save", "create_from"])
        .describe("Action to perform"),
      planId: z
        .string()
        .optional()
        .describe("Plan ID (for 'save')"),
      templateName: z
        .string()
        .optional()
        .describe("Template name (for 'save')"),
      templateId: z
        .string()
        .optional()
        .describe("Template ID (for 'create_from')"),
      title: z
        .string()
        .optional()
        .describe("New plan title (for 'create_from')"),
      startDate: z
        .string()
        .optional()
        .describe("Start date YYYY-MM-DD (for 'create_from')"),
      endDate: z
        .string()
        .optional()
        .describe("End date YYYY-MM-DD (for 'create_from')"),
    },
  },
  async (params) => {
    switch (params.action) {
      case "list": {
        const data = await api.call("planTemplatesList");
        return {
          content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
        };
      }
      case "save": {
        const data = await api.call("planTemplatesSave", {
          planId: params.planId,
          templateName: params.templateName,
        });
        return {
          content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
        };
      }
      case "create_from": {
        const data = await api.call("planTemplatesCreate", {
          templateId: params.templateId,
          title: params.title,
          startDate: params.startDate,
          endDate: params.endDate,
        });
        return {
          content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
        };
      }
    }
  }
);

// ═══════════════════════════════════════════════════════════════════
//  INVENTORY TOOLS
// ═══════════════════════════════════════════════════════════════════

server.registerTool(
  "list_inventory",
  {
    description:
      "List household inventory items. Optionally filter by category, location, low stock, or expiring soon.",
    inputSchema: {
      categoryId: z.string().optional().describe("Filter by category ID"),
      locationId: z.string().optional().describe("Filter by location ID"),
      lowStockOnly: z
        .boolean()
        .optional()
        .describe("Only show items below low stock threshold"),
      expiringOnly: z
        .boolean()
        .optional()
        .describe("Only show items expiring within 7 days"),
    },
  },
  async (params) => {
    const data = await api.call("inventoryList", params);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.registerTool(
  "get_inventory_item",
  {
    description:
      "Get a single inventory item with its category, location, and attachments.",
    inputSchema: {
      itemId: z.string().describe("The inventory item ID"),
    },
  },
  async ({ itemId }) => {
    const data = await api.call("inventoryGet", { itemId });
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.registerTool(
  "create_inventory_item",
  {
    description: "Add a new item to the household inventory.",
    inputSchema: {
      name: z.string().describe("Item name"),
      description: z.string().optional().describe("Item description"),
      categoryId: z.string().optional().describe("Category ID"),
      locationId: z.string().optional().describe("Location ID"),
      quantity: z.number().optional().describe("Initial quantity (default: 0)"),
      unit: z
        .string()
        .optional()
        .describe("Unit of measurement (default: pieces)"),
      lowStockThreshold: z
        .number()
        .optional()
        .describe("Threshold for low stock alerts"),
      barcode: z.string().optional().describe("Barcode value"),
      expiryDate: z.string().optional().describe("Expiry date (ISO 8601)"),
      purchaseDate: z.string().optional().describe("Purchase date (ISO 8601)"),
      notes: z.string().optional().describe("Additional notes"),
    },
  },
  async (params) => {
    const data = await api.call("inventoryCreate", params);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.registerTool(
  "update_inventory_item",
  {
    description:
      "Update an inventory item. Only provide fields you want to change.",
    inputSchema: {
      itemId: z.string().describe("Item ID to update"),
      name: z.string().optional().describe("New name"),
      description: z.string().optional().describe("New description"),
      categoryId: z.string().optional().describe("New category ID"),
      locationId: z.string().optional().describe("New location ID"),
      quantity: z.number().optional().describe("New quantity"),
      unit: z.string().optional().describe("New unit"),
      lowStockThreshold: z.number().optional().describe("New threshold"),
      expiryDate: z.string().optional().describe("New expiry date"),
      purchaseDate: z.string().optional().describe("New purchase date"),
      notes: z.string().optional().describe("New notes"),
    },
  },
  async (params) => {
    const data = await api.call("inventoryUpdate", params);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.registerTool(
  "delete_inventory_item",
  {
    description:
      "Delete an inventory item and all its logs/attachments. Irreversible.",
    inputSchema: {
      itemId: z.string().describe("Item ID to delete"),
    },
  },
  async ({ itemId }) => {
    await api.call("inventoryDelete", { itemId });
    return { content: [{ type: "text", text: `Item ${itemId} deleted.` }] };
  }
);

server.registerTool(
  "log_inventory_action",
  {
    description:
      "Log an inventory action (add, remove, adjust) and update stock.",
    inputSchema: {
      itemId: z.string().describe("Item ID"),
      action: z
        .enum(["added", "removed", "adjusted", "expired"])
        .describe("Type of inventory action"),
      quantityChange: z
        .number()
        .describe("Quantity change (positive or negative)"),
      quantityAfter: z.number().describe("Resulting quantity after change"),
      note: z.string().optional().describe("Optional note about the change"),
    },
  },
  async (params) => {
    await api.call("inventoryLogsCreate", params);
    return {
      content: [
        {
          type: "text",
          text: `Logged: ${params.action} ${params.quantityChange} → now ${params.quantityAfter}`,
        },
      ],
    };
  }
);

server.registerTool(
  "get_inventory_logs",
  {
    description: "Get the activity log for an inventory item.",
    inputSchema: {
      itemId: z.string().describe("Item ID"),
      limit: z
        .number()
        .optional()
        .describe("Max number of logs to return (default: 50)"),
    },
  },
  async (params) => {
    const data = await api.call("inventoryLogsList", params);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.registerTool(
  "get_inventory_stats",
  {
    description:
      "Get inventory statistics: total items, low stock, expiring soon, expired.",
    inputSchema: {},
  },
  async () => {
    const data = await api.call("inventoryStats");
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.registerTool(
  "manage_inventory_categories",
  {
    description: "List, create, or delete inventory categories.",
    inputSchema: {
      action: z.enum(["list", "create", "delete"]).describe("Action"),
      name: z.string().optional().describe("Category name (for create)"),
      icon: z.string().optional().describe("Material icon name (for create)"),
      color: z.string().optional().describe("Hex colour (for create)"),
      categoryId: z.string().optional().describe("Category ID (for delete)"),
    },
  },
  async (params) => {
    switch (params.action) {
      case "list": {
        const data = await api.call("inventoryCategoriesList");
        return {
          content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
        };
      }
      case "create": {
        const data = await api.call("inventoryCategoriesCreate", {
          name: params.name,
          icon: params.icon,
          color: params.color,
        });
        return {
          content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
        };
      }
      case "delete": {
        await api.call("inventoryCategoriesDelete", {
          categoryId: params.categoryId,
        });
        return { content: [{ type: "text", text: "Category deleted." }] };
      }
    }
  }
);

server.registerTool(
  "manage_inventory_locations",
  {
    description: "List, create, or delete inventory locations.",
    inputSchema: {
      action: z.enum(["list", "create", "delete"]).describe("Action"),
      name: z.string().optional().describe("Location name (for create)"),
      icon: z.string().optional().describe("Material icon name (for create)"),
      locationId: z.string().optional().describe("Location ID (for delete)"),
    },
  },
  async (params) => {
    switch (params.action) {
      case "list": {
        const data = await api.call("inventoryLocationsList");
        return {
          content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
        };
      }
      case "create": {
        const data = await api.call("inventoryLocationsCreate", {
          name: params.name,
          icon: params.icon,
        });
        return {
          content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
        };
      }
      case "delete": {
        await api.call("inventoryLocationsDelete", {
          locationId: params.locationId,
        });
        return { content: [{ type: "text", text: "Location deleted." }] };
      }
    }
  }
);

// ═══════════════════════════════════════════════════════════════════
//  SEARCH TOOL
// ═══════════════════════════════════════════════════════════════════

server.registerTool(
  "search",
  {
    description:
      "Search across all household data: tasks, checklists, plans, inventory, and attachments. Returns matching results sorted by relevance.",
    inputSchema: {
      query: z.string().describe("Search query (case-insensitive substring)"),
      entityTypes: z
        .array(
          z.enum(["task", "checklist", "plan", "attachment", "inventory"])
        )
        .optional()
        .describe(
          "Entity types to search (default: all)"
        ),
    },
  },
  async (params) => {
    const data = await api.call("searchAll", params);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

// ═══════════════════════════════════════════════════════════════════
//  ATTACHMENT TOOLS
// ═══════════════════════════════════════════════════════════════════

server.registerTool(
  "manage_attachments",
  {
    description:
      "Manage Google Drive attachments for tasks, plans, and inventory items. Create, list, or delete attachments.",
    inputSchema: {
      action: z
        .enum(["create_task", "list_task", "delete_task", "create_plan", "list_plan_entry", "list_plan", "delete_plan", "create_inventory", "list_inventory", "delete_inventory"])
        .describe("Attachment action"),
      // Common fields
      driveFileId: z.string().optional().describe("Google Drive file ID"),
      fileName: z.string().optional().describe("File name"),
      mimeType: z.string().optional().describe("MIME type"),
      fileSizeBytes: z.number().optional().describe("File size in bytes"),
      webViewLink: z.string().optional().describe("Web view link"),
      description: z.string().optional().describe("Description"),
      attachmentId: z.string().optional().describe("Attachment ID (for delete)"),
      // Entity-specific
      taskId: z.string().optional().describe("Task ID"),
      planId: z.string().optional().describe("Plan ID"),
      entryId: z.string().optional().describe("Plan entry ID"),
      itemId: z.string().optional().describe("Inventory item ID"),
    },
  },
  async (params) => {
    const { action, ...rest } = params;

    const actionMap: Record<string, string> = {
      create_task: "taskAttachmentsCreate",
      list_task: "taskAttachmentsList",
      delete_task: "taskAttachmentsDelete",
      create_plan: "planAttachmentsCreate",
      list_plan_entry: "planAttachmentsListByEntry",
      list_plan: "planAttachmentsListByPlan",
      delete_plan: "planAttachmentsDelete",
      create_inventory: "inventoryAttachmentsCreate",
      list_inventory: "inventoryAttachmentsList",
      delete_inventory: "inventoryAttachmentsDelete",
    };

    const endpoint = actionMap[action];
    if (!endpoint) {
      return { content: [{ type: "text", text: `Unknown action: ${action}` }] };
    }

    const data = await api.call(endpoint, rest);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

// ── Feedback & Diagnostics ────────────────────────────────────────

server.registerTool(
  "list_feedback",
  {
    description: "List user-submitted feedback entries for the household. Returns type, rating, message, and timestamp.",
    inputSchema: {
      limit: z.number().optional().describe("Maximum entries to return (default: 50)"),
      type: z.enum(["general", "aiResponse", "bug", "featureRequest"]).optional()
        .describe("Filter by feedback type"),
    },
  },
  async (params) => {
    const data = await api.call("feedbackList", params);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.registerTool(
  "get_diagnostic_stats",
  {
    description: "Get diagnostic statistics for the last 7 days: error count, warning count, feedback sentiment, positive/negative feedback breakdown.",
    inputSchema: {},
  },
  async () => {
    const data = await api.call("diagnosticStatsGet") as Record<string, unknown>;
    const message = `Diagnostic Stats (last 7 days)\n` +
      `Errors: ${data.errors}\n` +
      `Warnings: ${data.warnings}\n` +
      `Feedback: ${data.totalFeedback} total (${data.positiveFeedback} positive, ${data.negativeFeedback} negative)\n` +
      `Sentiment: ${data.feedbackSentiment != null ? data.feedbackSentiment + "%" : "N/A"}`;
    return { content: [{ type: "text", text: message }] };
  }
);

server.registerTool(
  "generate_weekly_digest",
  {
    description: "Generate a weekly digest summarising household activity over the last 7 days. Returns task, plan, inventory, manual, and feedback counts.",
    inputSchema: {},
  },
  async () => {
    const data = await api.call("weeklyDigestGenerate");
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.registerTool(
  "list_weekly_digests",
  {
    description: "List previous weekly digests for the household, most recent first.",
    inputSchema: {
      limit: z.number().optional().describe("Maximum digests to return (default: 12)"),
    },
  },
  async (params) => {
    const data = await api.call("weeklyDigestList", params);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

} // end _registerTools

function _registerResources(server: McpServer) {
// ═══════════════════════════════════════════════════════════════════
//  RESOURCES
// ═══════════════════════════════════════════════════════════════════

server.resource(
  "api-schema",
  "pacelli://schema",
  async () => ({
    contents: [
      {
        uri: "pacelli://schema",
        mimeType: "application/json",
        text: JSON.stringify(
          {
            name: "Pacelli Household Management API",
            version: "1.0.0",
            description:
              "API for managing household tasks, inventory, checklists, plans, and more. All data is end-to-end encrypted with AES-256-CBC.",
            entities: {
              task: {
                fields: [
                  "id",
                  "title",
                  "description",
                  "categoryId",
                  "priority (low/medium/high/urgent)",
                  "status (pending/in_progress/completed)",
                  "dueDate",
                  "startDate",
                  "assignedTo",
                  "isShared",
                  "recurrence (none/daily/weekly/monthly)",
                  "subtasks[]",
                ],
              },
              checklist: {
                fields: [
                  "id",
                  "title",
                  "items[].title",
                  "items[].quantity",
                  "items[].isChecked",
                ],
              },
              plan: {
                fields: [
                  "id",
                  "title",
                  "type (weekly/daily/custom)",
                  "status (draft/finalised)",
                  "startDate",
                  "endDate",
                  "entries[].title/label/description/entryDate",
                  "checklistItems[].title/quantity/isChecked",
                ],
              },
              inventoryItem: {
                fields: [
                  "id",
                  "name",
                  "description",
                  "categoryId",
                  "locationId",
                  "quantity",
                  "unit",
                  "lowStockThreshold",
                  "barcode",
                  "expiryDate",
                  "purchaseDate",
                  "notes",
                ],
              },
              manualEntry: {
                fields: [
                  "id",
                  "title",
                  "content (Markdown)",
                  "categoryId",
                  "tags[]",
                  "isPinned",
                  "createdBy",
                  "lastEditedBy",
                  "createdAt",
                  "updatedAt",
                ],
              },
              feedbackEntry: {
                fields: [
                  "id",
                  "type (general/aiResponse/bug/featureRequest)",
                  "rating (positive/negative/neutral)",
                  "message",
                  "context",
                  "createdBy",
                  "createdAt",
                ],
              },
              appDiagnostic: {
                fields: [
                  "id",
                  "kind (error/warning/performance/usage)",
                  "summary",
                  "detail",
                  "source",
                  "userId",
                  "createdAt",
                ],
              },
              weeklyDigest: {
                fields: [
                  "id",
                  "weekStarting",
                  "weekEnding",
                  "tasksCreated",
                  "tasksCompleted",
                  "plansCreated",
                  "inventoryItemsAdded",
                  "manualEntriesCreated",
                  "feedbackSubmitted",
                  "errorsLogged",
                  "summary",
                  "createdAt",
                ],
              },
            },
            encryption:
              "All human-readable fields are encrypted with AES-256-CBC using per-household keys. The server decrypts data so you see plaintext.",
          },
          null,
          2
        ),
      },
    ],
  })
);

server.resource(
  "household-summary",
  "pacelli://summary",
  async () => {
    try {
      const [taskStats, inventoryStats, checklists, plans] = await Promise.all([
        api.call<{ completed: number; pending: number; overdue: number; total: number }>("tasksStats"),
        api.call<{ totalItems: number; lowStock: number; expiringSoon: number; expired: number }>("inventoryStats"),
        api.call<unknown[]>("checklistsList"),
        api.call<unknown[]>("plansList"),
      ]);

      const summary = {
        tasks: taskStats,
        inventory: inventoryStats,
        checklists: { count: Array.isArray(checklists) ? checklists.length : 0 },
        plans: { count: Array.isArray(plans) ? plans.length : 0 },
      };

      return {
        contents: [
          {
            uri: "pacelli://summary",
            mimeType: "application/json",
            text: JSON.stringify(summary, null, 2),
          },
        ],
      };
    } catch {
      return {
        contents: [
          {
            uri: "pacelli://summary",
            mimeType: "text/plain",
            text: "Unable to fetch household summary. Check auth token.",
          },
        ],
      };
    }
  }
);
server.resource(
  "capabilities",
  "pacelli://capabilities",
  async () => ({
    contents: [
      {
        uri: "pacelli://capabilities",
        mimeType: "application/json",
        text: JSON.stringify(
          {
            name: "Pacelli Capabilities",
            version: "1.0.0",
            description:
              "Complete list of what Pacelli can do — for both humans and AI agents.",
            groups: [
              {
                group: "Tasks",
                icon: "✅",
                capabilities: [
                  { name: "Create & manage tasks", aiSupported: true },
                  { name: "Recurring tasks (daily/weekly/monthly)", aiSupported: true },
                  { name: "Priority levels (low/medium/high/urgent)", aiSupported: true },
                  { name: "Shared tasks across household members", aiSupported: true },
                  { name: "Subtasks for breaking down work", aiSupported: true },
                ],
              },
              {
                group: "Checklists",
                icon: "📝",
                capabilities: [
                  { name: "Shopping & packing lists with quantities", aiSupported: true },
                  { name: "Push checklist items as standalone tasks", aiSupported: true },
                ],
              },
              {
                group: "Plans",
                icon: "🗓️",
                capabilities: [
                  { name: "Multi-day trip & event planning", aiSupported: true },
                  { name: "Save & reuse plan templates", aiSupported: true },
                  { name: "Finalise plans to convert entries into tasks", aiSupported: true },
                ],
              },
              {
                group: "Inventory",
                icon: "📦",
                capabilities: [
                  { name: "Track items with quantities, categories, locations", aiSupported: true },
                  { name: "Expiry & low-stock alerts", aiSupported: true },
                  { name: "Barcode scanning", aiSupported: false },
                  { name: "Storage location management", aiSupported: true },
                ],
              },
              {
                group: "Calendar",
                icon: "📅",
                capabilities: [
                  { name: "Unified calendar view (tasks, plans, expiry)", aiSupported: false },
                  { name: "Push notification reminders", aiSupported: false },
                ],
              },
              {
                group: "AI Assistant",
                icon: "🤖",
                capabilities: [
                  { name: "In-app natural language chat", aiSupported: true },
                  { name: "MCP integration for external AI tools", aiSupported: true },
                ],
              },
              {
                group: "Security & Privacy",
                icon: "🔒",
                capabilities: [
                  { name: "AES-256-CBC end-to-end encryption", aiSupported: false },
                  { name: "Burn all data (one-tap wipe)", aiSupported: false },
                  { name: "Encrypted backup & restore", aiSupported: false },
                ],
              },
            ],
            aiToolsSummary: {
              totalTools: "25+",
              categories: [
                "list_tasks / get_task / create_task / update_task / complete_task / delete_task",
                "list_checklists / create_checklist / manage_checklist",
                "list_plans / get_plan / create_plan / manage_plan",
                "list_inventory / get_inventory_item / create_inventory_item / update_inventory_item",
                "search (cross-entity full-text search)",
                "get_task_stats / get_inventory_stats",
              ],
              resources: [
                "pacelli://schema — Data model reference",
                "pacelli://summary — Live household statistics",
                "pacelli://capabilities — This resource",
                "pacelli://diagnostics — Error/feedback/usage stats",
              ],
            },
          },
          null,
          2
        ),
      },
    ],
  })
);

// ── Diagnostic Summary (live) ──

server.resource(
  "diagnostic-summary",
  "pacelli://diagnostics",
  async () => {
    try {
      const stats = await api.call("diagnosticStatsGet") as Record<string, unknown>;
      return {
        contents: [
          {
            uri: "pacelli://diagnostics",
            mimeType: "application/json",
            text: JSON.stringify(
              {
                description:
                  "Real-time diagnostic summary: errors, warnings, and user feedback sentiment over the last 7 days.",
                ...stats,
              },
              null,
              2
            ),
          },
        ],
      };
    } catch (e: unknown) {
      const message = e instanceof Error ? e.message : String(e);
      return {
        contents: [
          {
            uri: "pacelli://diagnostics",
            mimeType: "text/plain",
            text: `Failed to load diagnostic summary: ${message}`,
          },
        ],
      };
    }
  }
);

} // end _registerResources

// ═══════════════════════════════════════════════════════════════════
//  START SERVER
// ═══════════════════════════════════════════════════════════════════

const mode = process.argv.includes("--http") ? "http" : "stdio";

async function startStdio() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Pacelli MCP server started (stdio transport)");
}

async function startHttp() {
  const PORT = parseInt(process.env.PORT ?? "3000", 10);
  const allowedOrigins = (process.env.MCP_ALLOWED_ORIGINS ?? "")
    .split(",")
    .map((o) => o.trim())
    .filter(Boolean);

  if (allowedOrigins.length === 0) {
    console.error("MCP_ALLOWED_ORIGINS must be set in HTTP mode");
    process.exit(1);
  }

  // Track active sessions: sessionId → transport
  const sessions = new Map<string, StreamableHTTPServerTransport>();

  // Session timeout tracking (30 minute TTL)
  const SESSION_TTL_MS = 30 * 60 * 1000;
  const sessionLastActivity = new Map<string, number>();

  // Rate limiting: max 100 requests per 60s per IP
  const RATE_LIMIT_WINDOW_MS = 60 * 1000;
  const RATE_LIMIT_MAX = 100;
  const rateLimitMap = new Map<string, { count: number; resetAt: number }>();

  // Periodic cleanup: expire idle sessions and stale rate-limit entries
  const cleanupInterval = setInterval(() => {
    const now = Date.now();

    // Expire idle sessions
    for (const [sid, lastActive] of sessionLastActivity) {
      if (now - lastActive > SESSION_TTL_MS) {
        const transport = sessions.get(sid);
        if (transport) {
          transport.close();
          sessions.delete(sid);
        }
        sessionLastActivity.delete(sid);
        console.error(`[MCP] Session expired (idle >30m): ${sid}`);
      }
    }

    // Clean up expired rate-limit entries
    for (const [ip, entry] of rateLimitMap) {
      if (now >= entry.resetAt) {
        rateLimitMap.delete(ip);
      }
    }
  }, 60_000);

  const httpServer = createServer(async (req: IncomingMessage, res: ServerResponse) => {
    const url = new URL(req.url ?? "/", `http://localhost:${PORT}`);

    // Health check
    if (url.pathname === "/health") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ status: "ok" }));
      return;
    }

    // Rate limiting
    const clientIp = (req.headers["x-forwarded-for"] as string)?.split(",")[0]?.trim() ?? req.socket.remoteAddress ?? "unknown";
    const now = Date.now();
    const rateEntry = rateLimitMap.get(clientIp);
    if (rateEntry && now < rateEntry.resetAt) {
      rateEntry.count++;
      if (rateEntry.count > RATE_LIMIT_MAX) {
        res.writeHead(429, { "Content-Type": "application/json", "Retry-After": String(Math.ceil((rateEntry.resetAt - now) / 1000)) });
        res.end(JSON.stringify({ error: "Too many requests" }));
        return;
      }
    } else {
      rateLimitMap.set(clientIp, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    }

    // MCP endpoint
    if (url.pathname !== "/mcp") {
      res.writeHead(404, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Not found. Use /mcp or /health" }));
      return;
    }

    // Origin validation (DNS rebinding protection)
    const origin = req.headers.origin;
    if (!origin || !allowedOrigins.includes(origin)) {
      res.writeHead(403, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Origin not allowed" }));
      return;
    }

    // CORS preflight
    if (req.method === "OPTIONS") {
      res.writeHead(204, {
        "Access-Control-Allow-Origin": origin,
        "Access-Control-Allow-Methods": "POST, GET, DELETE, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Accept, Mcp-Session-Id",
        "Access-Control-Max-Age": "86400",
      });
      res.end();
      return;
    }

    // Set CORS headers for all responses
    if (origin) {
      res.setHeader("Access-Control-Allow-Origin", origin);
      res.setHeader("Access-Control-Expose-Headers", "Mcp-Session-Id");
    }

    const sessionId = req.headers["mcp-session-id"] as string | undefined;

    // Update session activity timestamp
    if (sessionId && sessions.has(sessionId)) {
      sessionLastActivity.set(sessionId, Date.now());
    }

    if (req.method === "POST") {
      // Check for existing session
      if (sessionId && sessions.has(sessionId)) {
        const transport = sessions.get(sessionId)!;
        await transport.handleRequest(req, res);
        return;
      }

      // New session — create transport + connect a new server instance
      const transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: () => crypto.randomUUID(),
        onsessioninitialized: (sid) => {
          sessions.set(sid, transport);
          sessionLastActivity.set(sid, Date.now());
          console.error(`[MCP] Session created: ${sid}`);
        },
      });

      transport.onclose = () => {
        if (transport.sessionId) {
          sessions.delete(transport.sessionId);
          sessionLastActivity.delete(transport.sessionId);
          console.error(`[MCP] Session closed: ${transport.sessionId}`);
        }
      };

      // Each session gets its own server instance so tool state is isolated
      const sessionServer = new McpServer({
        name: "pacelli",
        version: "1.0.0",
      });

      // Re-register all tools/resources for this session's server
      registerToolsAndResources(sessionServer);

      await sessionServer.connect(transport);
      await transport.handleRequest(req, res);

    } else if (req.method === "GET") {
      // SSE stream for server-to-client messages
      if (sessionId && sessions.has(sessionId)) {
        const transport = sessions.get(sessionId)!;
        await transport.handleRequest(req, res);
      } else {
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Missing or invalid session ID" }));
      }

    } else if (req.method === "DELETE") {
      // Session termination
      if (sessionId && sessions.has(sessionId)) {
        const transport = sessions.get(sessionId)!;
        await transport.handleRequest(req, res);
        sessions.delete(sessionId);
        sessionLastActivity.delete(sessionId);
      } else {
        res.writeHead(404, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Session not found" }));
      }

    } else {
      res.writeHead(405, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Method not allowed" }));
    }
  });

  httpServer.listen(PORT, "0.0.0.0", () => {
    console.error(`Pacelli MCP server started (Streamable HTTP on port ${PORT})`);
    console.error(`  MCP endpoint: http://localhost:${PORT}/mcp`);
    console.error(`  Health check: http://localhost:${PORT}/health`);
  });

  httpServer.on("close", () => {
    clearInterval(cleanupInterval);
  });
}

async function main() {
  if (mode === "http") {
    await startHttp();
  } else {
    await startStdio();
  }
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
