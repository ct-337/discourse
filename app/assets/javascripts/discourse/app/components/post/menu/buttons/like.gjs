import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { avatarImg } from "discourse/lib/avatar-utils";
import discourseLater from "discourse/lib/later";
import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

export default class PostMenuLikeButton extends Component {
  static shouldRender(args) {
    const show = args.post.showLike || args.post.likeCount > 0;
    return applyValueTransformer("like-button-render-decision", show, {
      post: args.post,
    });
  }

  @service currentUser;
  @service store;

  @tracked isAnimated = false;
  @tracked likedUsers = null;
  @tracked totalLikedUsers = 0;
  @tracked loadingLikedUsers = false;

  get disabled() {
    return this.currentUser && !this.args.post.canToggleLike;
  }

  avatarImage(user) {
    return htmlSafe(
      avatarImg({
        avatarTemplate: user.avatar_template,
        size: "small",
        title: user.name,
      })
    );
  }

  get title() {
    // If the user has already liked the post and doesn't have permission
    // to undo that operation, then indicate via the title that they've liked it
    // and disable the button. Otherwise, set the title even if the user
    // is anonymous (meaning they don't currently have permission to like);
    // this is important for accessibility.

    if (this.args.post.liked && !this.args.post.canToggleLike) {
      return "post.controls.has_liked";
    }

    return this.args.post.liked
      ? "post.controls.undo_like"
      : "post.controls.like";
  }

  @action
  async toggleLike() {
    this.isAnimated = true;

    return new Promise((resolve) => {
      discourseLater(async () => {
        this.isAnimated = false;
        await this.args.buttonActions.toggleLike();
        resolve();
      }, 400);
    });
  }

  @action
  async fetchLikedUsers() {
    if (this.likedUsers || this.loadingLikedUsers) {
      return;
    }

    this.loadingLikedUsers = true;

    try {
      const users = await this.store
        .find("post-action-user", {
          id: this.args.post.id,
          post_action_type_id: 2, // LIKE_ACTION
        })
        .then((result) => result.toArray());

      this.likedUsers = users;
    } catch {
      // Silently handle error - could add user notification here if needed
    } finally {
      this.loadingLikedUsers = false;
    }
  }

  <template>
    {{#if @post.showLike}}
      <div class="double-button">
        {{#if @post.likeCount}}
          <DMenu
            @modalForMobile={{true}}
            @identifier="post-like-users"
            @triggers="click"
            @onShow={{this.fetchLikedUsers}}
            @triggerClass="button-count"
          >
            <:trigger>
              {{@post.likeCount}}
            </:trigger>
            <:content>
              <ConditionalLoadingSpinner @condition={{this.loadingLikedUsers}}>
                <ul class="liked-users-list">
                  {{#each this.likedUsers as |user|}}
                    <li class="liked-user">
                      {{this.avatarImage user}}
                    </li>
                  {{/each}}
                </ul>
              </ConditionalLoadingSpinner>
            </:content>
          </DMenu>
        {{else}}
          <LikeCount
            ...attributes
            @action={{@buttonActions.toggleWhoLiked}}
            @state={{@state}}
            @post={{@post}}
          />
        {{/if}}
        <DButton
          class={{concatClass
            "post-action-menu__like"
            "toggle-like"
            "btn-icon"
            (if this.isAnimated "heart-animation")
            (if @post.liked "has-like" "like")
          }}
          ...attributes
          data-post-id={{@post.id}}
          disabled={{this.disabled}}
          @action={{this.toggleLike}}
          @icon={{if @post.liked "d-liked" "d-unliked"}}
          @label={{if @showLabel "post.controls.like_action"}}
          @title={{this.title}}
        />
      </div>
    {{else}}
      <div class="double-button">
        {{#if @post.likeCount}}
          <DMenu
            @modalForMobile={{true}}
            @identifier="post-like-users"
            @triggers="click"
          >
            <:trigger>
              <LikeCount
                ...attributes
                @post={{@post}}
                @fetchLikedUsers={{this.fetchLikedUsers}}
              />
            </:trigger>
            <:content>
              <ConditionalLoadingSpinner @condition={{this.loadingLikedUsers}}>
                <ul class="liked-users-list">
                  {{#each this.likedUsers as |user|}}
                    <li class="liked-user">
                      {{this.avatarImage user}}
                    </li>
                  {{/each}}
                </ul>
              </ConditionalLoadingSpinner>
            </:content>
          </DMenu>
        {{else}}
          <LikeCount
            ...attributes
            @action={{@buttonActions.toggleWhoLiked}}
            @state={{@state}}
            @post={{@post}}
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}

class LikeCount extends Component {
  get icon() {
    if (!this.args.post.showLike) {
      return this.args.post.yours ? "d-liked" : "d-unliked";
    }

    if (this.args.post.yours) {
      return "d-liked";
    }
  }

  get translatedTitle() {
    let title;

    if (this.args.post.liked) {
      title =
        this.args.post.likeCount === 1
          ? "post.has_likes_title_only_you"
          : "post.has_likes_title_you";
    } else {
      title = "post.has_likes_title";
    }

    return i18n(title, {
      count: this.args.post.liked
        ? this.args.post.likeCount - 1
        : this.args.post.likeCount,
    });
  }

  @action
  handleLikeCountClick() {
    if (this.args.fetchLikedUsers) {
      this.args.fetchLikedUsers();
    }
    if (this.args.action) {
      this.args.action();
    }
  }

  <template>
    {{#if @post.likeCount}}
      <DButton
        class={{concatClass
          "post-action-menu__like-count"
          "like-count"
          "button-count"
          "highlight-action"
          (if @post.yours "my-likes" "regular-likes")
        }}
        ...attributes
        @translatedAriaLabel={{i18n
          "post.sr_post_like_count_button"
          count=@post.likeCount
        }}
        @translatedTitle={{this.translatedTitle}}
        @action={{this.handleLikeCountClick}}
      >
        {{@post.likeCount}}
        {{!--
           When displayed, the icon on the Like Count button is aligned to the right
           To get the desired effect will use the {{yield}} in the DButton component to our advantage
           introducing manually the icon after the label
          --}}
        {{#if this.icon}}
          {{~icon this.icon~}}
        {{/if}}
      </DButton>
    {{/if}}
  </template>
}
