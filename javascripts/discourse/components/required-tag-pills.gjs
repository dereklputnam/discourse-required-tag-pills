import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { set } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

// Module-level cache persists across component instances in a session
const tagGroupCache = new Map();

export default class RequiredTagPills extends Component {
  @tracked tagGroupTags = [];

  constructor(owner, args) {
    super(owner, args);
    this.#loadTagGroup();
  }

  get #groupName() {
    return settings.required_tag_group_name?.trim() || "";
  }

  get #targetCategoryIds() {
    const raw = settings.target_category_ids?.trim();
    if (!raw) return null; // null means all categories
    return raw.split(",").map((id) => parseInt(id.trim(), 10)).filter(Boolean);
  }

  get #isApplicableCategory() {
    const ids = this.#targetCategoryIds;
    if (!ids) return true;
    return ids.includes(this.args.composer?.categoryId);
  }

  get shouldShow() {
    return this.#isApplicableCategory && this.tagGroupTags.length > 0;
  }

  get selectedTag() {
    const tags = this.args.composer?.tags || [];
    return this.tagGroupTags.find((t) => tags.includes(t)) || null;
  }

  async #loadTagGroup() {
    const groupName = this.#groupName;
    if (!groupName) return;

    if (tagGroupCache.has(groupName)) {
      this.tagGroupTags = tagGroupCache.get(groupName);
      return;
    }

    try {
      const response = await ajax("/tag_groups.json");
      const group = response.tag_groups?.find((g) => g.name === groupName);
      const tags = group?.tag_names || [];
      tagGroupCache.set(groupName, tags);
      this.tagGroupTags = tags;
    } catch {
      // fail silently if tag group not found
    }
  }

  @action
  selectTag(tagName) {
    const composer = this.args.composer;
    if (!composer) return;

    const currentTags = [...(composer.tags || [])];
    const isSelected = currentTags.includes(tagName);

    // Remove any previously selected pill tag
    const filtered = currentTags.filter((t) => !this.tagGroupTags.includes(t));

    if (!isSelected) {
      filtered.push(tagName);
    }

    set(composer, "tags", filtered);
  }

  <template>
    {{#if this.shouldShow}}
      <div class="required-tag-pills">
        {{#each this.tagGroupTags as |tag|}}
          <button
            type="button"
            class="tag-pill {{if (eq tag this.selectedTag) 'selected'}}"
            {{on "click" (fn this.selectTag tag)}}
          >
            {{tag}}
          </button>
        {{/each}}
      </div>
    {{/if}}
  </template>
}
