import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { set } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

// One fetch per session, shared across all component instances
let tagGroupsDataCache = null;
let tagGroupsLoadPromise = null;

export default class RequiredTagPills extends Component {
  @service site;

  @tracked _tagGroupsData = null;

  constructor(owner, args) {
    super(owner, args);
    this._ensureTagGroupsLoaded();
  }

  get _targetCategoryIds() {
    const raw = settings.target_category_ids?.trim();
    if (!raw) return null; // null = apply to all categories
    return raw.split(",").map((id) => parseInt(id.trim(), 10)).filter(Boolean);
  }

  get _isApplicableCategory() {
    const ids = this._targetCategoryIds;
    if (!ids) return true;
    return ids.includes(this.args.composer?.categoryId);
  }

  get _currentCategory() {
    const categoryId = this.args.composer?.categoryId;
    if (!categoryId) return null;
    return this.site.categories.find((c) => c.id === categoryId) || null;
  }

  get _requiredGroupNames() {
    return (this._currentCategory?.required_tag_groups || []).map(
      (g) => g.name
    );
  }

  get tagGroupTags() {
    if (!this._tagGroupsData) return [];
    const names = this._requiredGroupNames;
    if (!names.length) return [];
    return this._tagGroupsData.tag_groups
      .filter((g) => names.includes(g.name))
      .flatMap((g) => g.tag_names || []);
  }

  get shouldShow() {
    return this._isApplicableCategory && this.tagGroupTags.length > 0;
  }

  get selectedTag() {
    const tags = this.args.composer?.tags || [];
    return this.tagGroupTags.find((t) => tags.includes(t)) || null;
  }

  async _ensureTagGroupsLoaded() {
    if (tagGroupsDataCache) {
      this._tagGroupsData = tagGroupsDataCache;
      return;
    }
    if (!tagGroupsLoadPromise) {
      tagGroupsLoadPromise = ajax("/tag_groups.json")
        .then((data) => {
          tagGroupsDataCache = data;
          return data;
        })
        .catch(() => {
          tagGroupsLoadPromise = null; // allow retry on next mount
          return null;
        });
    }
    const data = await tagGroupsLoadPromise;
    if (data) {
      this._tagGroupsData = data;
    }
  }

  @action
  selectTag(tagName) {
    const composer = this.args.composer;
    if (!composer) return;

    const currentTags = [...(composer.tags || [])];
    const isSelected = currentTags.includes(tagName);

    // Remove any previously selected tag from this required group
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
