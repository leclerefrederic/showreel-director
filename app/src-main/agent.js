// Agent loop on the Messages API: streams text, runs tools, repeats until the model stops.
const { systemPrompt } = require("./skill");
const { makeTools } = require("./tools");

class Agent {
  constructor({ client, model = "claude-sonnet-5-5", project, ui, env = {}, lang, maxTokens = 8000 }) {
    this.client = client; this.model = model; this.ui = ui; this.messages = []; this.maxTokens = maxTokens;
    const sp = systemPrompt(project, lang);
    this.system = [{ type: "text", text: sp.text, cache_control: { type: "ephemeral" } }];
    this.tools = makeTools({ project, skill: sp.root, ui, env });
    this.aborted = false;
  }
  abort() { this.aborted = true; }

  async send(text) {
    this.aborted = false;
    this.messages.push({ role: "user", content: text });
    for (let turn = 0; turn < 60 && !this.aborted; turn++) {
      const stream = this.client.messages.stream({
        model: this.model, max_tokens: this.maxTokens, system: this.system,
        tools: this.tools.defs, messages: this.messages,
      });
      stream.on("text", t => this.ui.text(t));
      const msg = await stream.finalMessage();
      this.messages.push({ role: "assistant", content: msg.content });
      this.ui.endText();
      const uses = msg.content.filter(b => b.type === "tool_use");
      if (msg.stop_reason !== "tool_use" || !uses.length) return msg;
      const results = [];
      for (const u of uses) {
        this.ui.tool(u.name, u.input);
        const out = await this.tools.run(u.name, u.input);
        results.push({ type: "tool_result", tool_use_id: u.id, content: String(out) });
      }
      this.messages.push({ role: "user", content: results });
    }
    this.ui.text("\n[stopped]"); this.ui.endText();
  }
}
module.exports = { Agent };
