require 'rails_helper'

describe Admin::UsersController do
  it "requires to be signed in as an admin" do
    login_as(users(:bob))
    visit admin_users_path
    expect(page).to have_text('Admin access required to view that page.')
  end

  context "as an admin" do
    before :each do
      login_as(users(:jane))
    end

    it "lists all users" do
      visit admin_users_path
      expect(page).to have_text('bob')
      expect(page).to have_text('jane')
    end

    it "allows to delete a user" do
      visit admin_users_path
      find(:css, "a[href='/admin/users/#{users(:bob).id}']").click
      expect(page).to have_text("User 'bob' was deleted.")
      expect(page).to have_no_text('bob@example.com')
    end

    context "creating new users" do
      it "follow the 'new user' link" do
        visit admin_users_path
        click_on('New User')
        expect(page).to have_text('Create new User')
      end

      it "creates a new user" do
        visit new_admin_user_path
        fill_in 'Email', with: 'test@test.com'
        fill_in 'Username', with: 'usertest'
        fill_in 'Password', with: '12345678'
        fill_in 'Password confirmation', with: '12345678'
        click_on 'Create User'
        expect(page).to have_text("User 'usertest' was successfully created.")
        expect(page).to have_text('test@test.com')
      end

      it "requires the passwords to match" do
        visit new_admin_user_path
        fill_in 'Email', with: 'test@test.com'
        fill_in 'Username', with: 'usertest'
        fill_in 'Password', with: '12345678'
        fill_in 'Password confirmation', with: 'no_match'
        click_on 'Create User'
        expect(page).to have_text("Password confirmation doesn't match")
      end
    end

    context "updating existing users" do
      it "follows the edit link" do
        visit admin_users_path
        click_on('bob')
        expect(page).to have_text('Edit User')
      end

      it "updates an existing user" do
        visit edit_admin_user_path(users(:bob))
        check 'Admin'
        click_on 'Update User'
        expect(page).to have_text("User 'bob' was successfully updated.")
        visit edit_admin_user_path(users(:bob))
        expect(page).to have_checked_field('Admin')
      end

      it "requires the passwords to match when changing them" do
        visit edit_admin_user_path(users(:bob))
        fill_in 'Password', with: '12345678'
        fill_in 'Password confirmation', with: 'no_match'
        click_on 'Update User'
        expect(page).to have_text("Password confirmation doesn't match")
      end
    end

    context "(de)activating users" do
      it "does not show deactivation buttons for the current user" do
        visit admin_users_path
        expect(page).to have_no_css("a[href='/admin/users/#{users(:jane).id}/deactivate']")
      end

      it "deactivates an existing user" do
        visit admin_users_path
        expect(page).to have_no_text('inactive')
        find(:css, "a[href='/admin/users/#{users(:bob).id}/deactivate']").click
        expect(page).to have_text('inactive')
        users(:bob).reload
        expect(users(:bob)).not_to be_active
      end

      it "activates an existing user" do
        users(:bob).deactivate!
        visit admin_users_path
        find(:css, "a[href='/admin/users/#{users(:bob).id}/activate']").click
        expect(page).to have_no_text('inactive')
        users(:bob).reload
        expect(users(:bob)).to be_active
      end
    end
  end
end
