require 'rails_helper'

feature 'Submission Builder', js: true do
  include UserSpecHelper
  include MarkdownEditorHelper
  include NotificationHelper

  let(:course) { create :course }
  let(:grade_labels_for_1) { [{ 'grade' => 1, 'label' => 'Bad' }, { 'grade' => 2, 'label' => 'Good' }, { 'grade' => 3, 'label' => 'Great' }, { 'grade' => 4, 'label' => 'Wow' }] }
  let!(:criterion_1) { create :evaluation_criterion, course: course, max_grade: 4, pass_grade: 2, grade_labels: grade_labels_for_1 }
  let!(:level_1) { create :level, :one, course: course }
  let!(:team) { create :startup, level: level_1 }
  let!(:student) { team.founders.first }
  let!(:target_group_l1) { create :target_group, level: level_1, milestone: true }
  let!(:target) { create :target, :with_content, target_group: target_group_l1, role: Target::ROLE_TEAM, evaluation_criteria: [criterion_1] }

  scenario 'student submits a target with no checklist' do
    target.update!(checklist: [])

    sign_in_user student.user, referer: target_path(target)

    # This target should have a 'Complete' section.
    find('.course-overlay__body-tab-item', text: 'Complete').click

    expect(page).to have_text("This target has no actions. Click submit to complete the target")

    click_button 'Submit'

    expect(page).to have_content('Your submission has been queued for review')

    last_submission = TimelineEvent.last
    expect(last_submission.checklist).to eq([])

    # The submission contents should be on the page.
    expect(page).to have_content("Target was marked as complete.")
  end

  scenario 'student submits a target with long text' do
    question = Faker::Lorem.sentence
    target.update!(checklist: [{ title: question, kind: Target::CHECKLIST_KIND_LONG_TEXT, optional: false }])
    long_answer = Faker::Lorem.sentence

    sign_in_user student.user, referer: target_path(target)

    # This target should have a 'Complete' section.
    find('.course-overlay__body-tab-item', text: 'Complete').click

    within("div[aria-label='0-longText'") do
      expect(page).to have_content(question)
    end

    # The submit button should be disabled at this point.
    expect(page).to have_button('Submit', disabled: true)

    # Filling in with a bunch of spaces should not work.
    fill_in question, with: '   '

    expect(page).to have_button('Submit', disabled: true)

    # The user should be able to write text as description
    fill_in question, with: long_answer

    click_button 'Submit'

    expect(page).to have_content('Your submission has been queued for review')

    last_submission = TimelineEvent.last
    expect(last_submission.checklist).to eq([{ "kind" => Target::CHECKLIST_KIND_LONG_TEXT, "title" => question, "result" => long_answer, "status" => "noAnswer" }])

    expect(page).to have_text('Your Submissions')
    expect(page).to have_text(question)
    expect(page).to have_text(long_answer)
  end

  scenario 'student submits a target with short text' do
    question = Faker::Lorem.sentence
    target.update!(checklist: [{ title: question, kind: Target::CHECKLIST_KIND_SHORT_TEXT, optional: false }])
    short_answer = Faker::Lorem.words.join(' ')

    sign_in_user student.user, referer: target_path(target)

    # This target should have a 'Complete' section.
    find('.course-overlay__body-tab-item', text: 'Complete').click

    within("div[aria-label='0-shortText'") do
      expect(page).to have_content(question)
    end

    # The submit button should be disabled at this point.
    expect(page).to have_button('Submit', disabled: true)

    # Filling in with a bunch of spaces should not work.
    fill_in question, with: '   '

    expect(page).to have_button('Submit', disabled: true)

    # The user should be able to write text as description
    fill_in question, with: short_answer

    click_button 'Submit'

    expect(page).to have_content('Your submission has been queued for review')

    last_submission = TimelineEvent.last
    expect(last_submission.checklist).to eq([{ "kind" => Target::CHECKLIST_KIND_SHORT_TEXT, "title" => question, "result" => short_answer, "status" => "noAnswer" }])

    expect(page).to have_text('Your Submissions')
    expect(page).to have_text(question)
    expect(page).to have_text(short_answer)
  end

  scenario 'student submits a target with a link' do
    question = Faker::Lorem.sentence
    target.update!(checklist: [{ title: question, kind: Target::CHECKLIST_KIND_ATTACH_LINKS, optional: false }])
    link = 'https://example.com?q=1'

    sign_in_user student.user, referer: target_path(target)

    # This target should have a 'Complete' section.
    find('.course-overlay__body-tab-item', text: 'Complete').click

    within("div[aria-label='0-link'") do
      expect(page).to have_content(question)
    end

    # The submit button should be disabled at this point.
    expect(page).to have_button('Submit', disabled: true)

    # Filling in with a bunch of spaces should not work.
    fill_in question, with: '   '

    expect(page).to have_button('Submit', disabled: true)

    fill_in question, with: 'foobar'

    expect(page).to have_content("This doesn't look like a valid URL.")

    fill_in question, with: link

    click_button 'Submit'

    expect(page).to have_content('Your submission has been queued for review')

    last_submission = TimelineEvent.last
    expect(last_submission.checklist).to eq([{ "kind" => Target::CHECKLIST_KIND_ATTACH_LINKS, "title" => question, "result" => link, "status" => "noAnswer" }])

    expect(page).to have_text('Your Submissions')
    expect(page).to have_text(question)
    expect(page).to have_text(link)
  end

  scenario 'student submits a target with files' do
    question = Faker::Lorem.sentence
    target.update!(checklist: [{ title: question, kind: Target::CHECKLIST_KIND_ATTACH_FILES, optional: false }])

    sign_in_user student.user, referer: target_path(target)

    # This target should have a 'Complete' section.
    find('.course-overlay__body-tab-item', text: 'Complete').click

    within("div[aria-label='0-files'") do
      expect(page).to have_content(question)
      expect(page).to have_content('Choose file to upload')
    end

    # The submit button should be disabled at this point.
    expect(page).to have_button('Submit', disabled: true)

    attach_file 'attachment_file', File.absolute_path(Rails.root.join('spec/support/uploads/faculty/human.png')), visible: false
    expect(page).to have_text('human')
    attach_file 'attachment_file', File.absolute_path(Rails.root.join('spec/support/uploads/faculty/minnie_mouse.jpg')), visible: false
    expect(page).to have_text('minnie_mouse')
    attach_file 'attachment_file', File.absolute_path(Rails.root.join('spec/support/uploads/faculty/mickey_mouse.jpg')), visible: false
    expect(page).to have_text('mickey_mouse')

    # The attachment forms should have disappeared now.
    expect(page).not_to have_content('Choose file to upload')

    # Student can delete attached submissions
    click_button 'Remove human'

    expect(page).to have_content('Choose file to upload')

    click_button 'Submit'

    expect(page).to have_content('Your submission has been queued for review')

    last_submission = TimelineEvent.last
    expect(last_submission.checklist).to eq([{ "kind" => Target::CHECKLIST_KIND_ATTACH_FILES, "title" => question, "result" => "files", "status" => "noAnswer" }])

    expect(page).to have_text('Your Submissions')
    expect(page).to have_text(question)
    expect(page).to have_link('mickey_mouse.jpg', href: "/timeline_event_files/#{TimelineEventFile.last.id}/download")
    expect(page).to have_text('minnie_mouse')
    expect(page).to have_text('mickey_mouse')
  end

  scenario 'student submits a target with a choice' do
    question = Faker::Lorem.sentence
    choices = Faker::Lorem.words
    target.update!(checklist: [{ title: question, kind: Target::CHECKLIST_KIND_MULTI_CHOICE, optional: false, metadata: choices }])
    answer = choices.last

    sign_in_user student.user, referer: target_path(target)

    # This target should have a 'Complete' section.
    find('.course-overlay__body-tab-item', text: 'Complete').click

    within("div[aria-label='0-multiChoice'") do
      expect(page).to have_content(question)
    end

    # The submit button should be disabled at this point.
    expect(page).to have_button('Submit', disabled: true)

    find("label", text: answer).click

    click_button 'Submit'

    expect(page).to have_content('Your submission has been queued for review')

    last_submission = TimelineEvent.last
    expect(last_submission.checklist).to eq([{ "kind" => Target::CHECKLIST_KIND_MULTI_CHOICE, "title" => question, "result" => answer, "status" => "noAnswer" }])

    expect(page).to have_text('Your Submissions')
    expect(page).to have_text(question)
    expect(page).to have_text(answer)
  end

  scenario 'student visits a target with a checklist kind multi choice' do
    question = Faker::Lorem.sentence
    choices = Faker::Lorem.words
    target.update!(checklist: [{ title: question, kind: Target::CHECKLIST_KIND_MULTI_CHOICE, optional: false, metadata: choices }])
    answer = choices.last

    sign_in_user student.user, referer: target_path(target)

    # This target should have a 'Complete' section.
    find('.course-overlay__body-tab-item', text: 'Complete').click

    within("div[aria-label='0-multiChoice'") do
      expect(page).to have_content(question)
    end

    # The submit button should be disabled at this point.
    expect(page).to have_button('Submit', disabled: true)

    find("label", text: answer).click

    click_button 'Submit'

    expect(page).to have_content('Your submission has been queued for review')

    last_submission = TimelineEvent.last
    expect(last_submission.checklist).to eq([{ "kind" => Target::CHECKLIST_KIND_MULTI_CHOICE, "title" => question, "result" => answer, "status" => "noAnswer" }])

    expect(page).to have_text('Your Submissions')
    expect(page).to have_text(question)
    expect(page).to have_text(answer)
  end

  scenario 'student submits a target with long text and skips a link' do
    question_1 = Faker::Lorem.sentence
    question_2 = Faker::Lorem.sentence
    target.update!(checklist: [{ title: question_1, kind: Target::CHECKLIST_KIND_LONG_TEXT, optional: false }, { title: question_2, kind: Target::CHECKLIST_KIND_ATTACH_LINKS, optional: true }])
    long_answer = Faker::Lorem.sentence

    sign_in_user student.user, referer: target_path(target)

    # This target should have a 'Complete' section.
    find('.course-overlay__body-tab-item', text: 'Complete').click

    within("div[aria-label='0-longText'") do
      expect(page).to have_content(question_1)
    end

    within("div[aria-label='1-link'") do
      expect(page).to have_content(question_2)
    end

    # The submit button should be disabled at this point.
    expect(page).to have_button('Submit', disabled: true)

    # The user should be able to write text as description
    fill_in question_1, with: long_answer

    # The submit button should be enabled at this point.
    expect(page).to have_button('Submit', disabled: false)

    fill_in question_2, with: 'foobar'

    expect(page).to have_content("This doesn't look like a valid URL.")

    # The submit button should be disabled at this point.
    expect(page).to have_button('Submit', disabled: true)

    fill_in question_2, with: 'https://example.com?q=1'

    # The submit button should be enabled at this point.
    expect(page).to have_button('Submit', disabled: false)

    fill_in question_2, with: ''

    click_button 'Submit'

    expect(page).to have_content('Your submission has been queued for review')

    last_submission = TimelineEvent.last
    expect(last_submission.checklist).to eq([{ "kind" => Target::CHECKLIST_KIND_LONG_TEXT, "title" => question_1, "result" => long_answer, "status" => "noAnswer" }])

    expect(page).to have_text('Your Submissions')
    expect(page).to have_text(question_1)
    expect(page).to have_text(long_answer)
    expect(page).not_to have_text(question_2)
  end
end
