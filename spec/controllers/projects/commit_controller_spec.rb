require 'spec_helper'

describe Projects::CommitController do
  let(:project) { create(:project) }
  let(:user)    { create(:user) }
  let(:commit)  { project.commit("master") }
  let(:master_pickable_sha) { '7d3b0f7cff5f37573aea97cebfd5692ea1689924' }
  let(:master_pickable_commit)  { project.commit(master_pickable_sha) }

  before do
    sign_in(user)
    project.team << [user, :master]
  end

  describe 'GET show' do
    render_views

    def go(extra_params = {})
      params = {
        namespace_id: project.namespace.to_param,
        project_id: project.to_param
      }

      get :show, params.merge(extra_params)
    end

    let(:project) { create(:project) }

    before do
      user = create(:user)
      project.team << [user, :master]

      sign_in(user)
    end

    context 'with valid id' do
      it 'responds with 200' do
        go(id: commit.id)

        expect(response).to be_ok
      end
    end

    context 'with invalid id' do
      it 'responds with 404' do
        go(id: commit.id.reverse)

        expect(response).to be_not_found
      end
    end

    it 'handles binary files' do
      go(id: TestEnv::BRANCH_SHA['binary-encoding'], format: 'html')

      expect(response).to be_success
    end

    shared_examples "export as" do |format|
      it "should generally work" do
        go(id: commit.id, format: format)

        expect(response).to be_success
      end

      it "should generate it" do
        expect_any_instance_of(Commit).to receive(:"to_#{format}")

        go(id: commit.id, format: format)
      end

      it "should render it" do
        go(id: commit.id, format: format)

        expect(response.body).to eq(commit.send(:"to_#{format}"))
      end

      it "should not escape Html" do
        allow_any_instance_of(Commit).to receive(:"to_#{format}").
          and_return('HTML entities &<>" ')

        go(id: commit.id, format: format)

        expect(response.body).not_to include('&amp;')
        expect(response.body).not_to include('&gt;')
        expect(response.body).not_to include('&lt;')
        expect(response.body).not_to include('&quot;')
      end
    end

    describe "as diff" do
      it "trigger workhorse to serve the request" do
        go(id: commit.id, format: :diff)

        expect(response.headers[Gitlab::Workhorse::SEND_DATA_HEADER]).to start_with("git-diff:")
      end
    end

    describe "as patch" do
      it "should contain a git diff" do
        go(id: commit.id, format: :patch)

        expect(response.headers[Gitlab::Workhorse::SEND_DATA_HEADER]).to start_with("git-format-patch:")
      end
    end

    context 'commit that removes a submodule' do
      render_views

      let(:fork_project) { create(:forked_project_with_submodules, visibility_level: 20) }
      let(:commit) { fork_project.commit('remove-submodule') }

      it 'renders it' do
        get(:show,
            namespace_id: fork_project.namespace.to_param,
            project_id: fork_project.to_param,
            id: commit.id)

        expect(response).to be_success
      end
    end
  end

  describe "GET branches" do
    it "contains branch and tags information" do
      get(:branches,
          namespace_id: project.namespace.to_param,
          project_id: project.to_param,
          id: commit.id)

      expect(assigns(:branches)).to include("master", "feature_conflict")
      expect(assigns(:tags)).to include("v1.1.0")
    end
  end

  describe 'POST revert' do
    context 'when target branch is not provided' do
      it 'should render the 404 page' do
        post(:revert,
            namespace_id: project.namespace.to_param,
            project_id: project.to_param,
            id: commit.id)

        expect(response).not_to be_success
        expect(response).to have_http_status(404)
      end
    end

    context 'when the revert was successful' do
      it 'should redirect to the commits page' do
        post(:revert,
            namespace_id: project.namespace.to_param,
            project_id: project.to_param,
            target_branch: 'master',
            id: commit.id)

        expect(response).to redirect_to namespace_project_commits_path(project.namespace, project, 'master')
        expect(flash[:notice]).to eq('The commit has been successfully reverted.')
      end
    end

    context 'when the revert failed' do
      before do
        post(:revert,
            namespace_id: project.namespace.to_param,
            project_id: project.to_param,
            target_branch: 'master',
            id: commit.id)
      end

      it 'should redirect to the commit page' do
        # Reverting a commit that has been already reverted.
        post(:revert,
            namespace_id: project.namespace.to_param,
            project_id: project.to_param,
            target_branch: 'master',
            id: commit.id)

        expect(response).to redirect_to namespace_project_commit_path(project.namespace, project, commit.id)
        expect(flash[:alert]).to match('Sorry, we cannot revert this commit automatically.')
      end
    end
  end

  describe 'POST cherry_pick' do
    context 'when target branch is not provided' do
      it 'should render the 404 page' do
        post(:cherry_pick,
            namespace_id: project.namespace.to_param,
            project_id: project.to_param,
            id: master_pickable_commit.id)

        expect(response).not_to be_success
        expect(response).to have_http_status(404)
      end
    end

    context 'when the cherry-pick was successful' do
      it 'should redirect to the commits page' do
        post(:cherry_pick,
            namespace_id: project.namespace.to_param,
            project_id: project.to_param,
            target_branch: 'master',
            id: master_pickable_commit.id)

        expect(response).to redirect_to namespace_project_commits_path(project.namespace, project, 'master')
        expect(flash[:notice]).to eq('The commit has been successfully cherry-picked.')
      end
    end

    context 'when the cherry_pick failed' do
      before do
        post(:cherry_pick,
            namespace_id: project.namespace.to_param,
            project_id: project.to_param,
            target_branch: 'master',
            id: master_pickable_commit.id)
      end

      it 'should redirect to the commit page' do
        # Cherry-picking a commit that has been already cherry-picked.
        post(:cherry_pick,
            namespace_id: project.namespace.to_param,
            project_id: project.to_param,
            target_branch: 'master',
            id: master_pickable_commit.id)

        expect(response).to redirect_to namespace_project_commit_path(project.namespace, project, master_pickable_commit.id)
        expect(flash[:alert]).to match('Sorry, we cannot cherry-pick this commit automatically.')
      end
    end
  end

  describe 'GET diff_for_path' do
    def diff_for_path(extra_params = {})
      params = {
        namespace_id: project.namespace.to_param,
        project_id: project.to_param
      }

      get :diff_for_path, params.merge(extra_params)
    end

    let(:existing_path) { '.gitmodules' }

    context 'when the commit exists' do
      context 'when the user has access to the project' do
        context 'when the path exists in the diff' do
          it 'enables diff notes' do
            diff_for_path(id: commit.id, old_path: existing_path, new_path: existing_path)

            expect(assigns(:diff_notes_disabled)).to be_falsey
            expect(assigns(:comments_target)).to eq(noteable_type: 'Commit',
                                                    commit_id: commit.id)
          end

          it 'only renders the diffs for the path given' do
            expect(controller).to receive(:render_diff_for_path).and_wrap_original do |meth, diffs, diff_refs, project|
              expect(diffs.map(&:new_path)).to contain_exactly(existing_path)
              meth.call(diffs, diff_refs, project)
            end

            diff_for_path(id: commit.id, old_path: existing_path, new_path: existing_path)
          end
        end

        context 'when the path does not exist in the diff' do
          before { diff_for_path(id: commit.id, old_path: existing_path.succ, new_path: existing_path.succ) }

          it 'returns a 404' do
            expect(response).to have_http_status(404)
          end
        end
      end

      context 'when the user does not have access to the project' do
        before do
          project.team.truncate
          diff_for_path(id: commit.id, old_path: existing_path, new_path: existing_path)
        end

        it 'returns a 404' do
          expect(response).to have_http_status(404)
        end
      end
    end

    context 'when the commit does not exist' do
      before { diff_for_path(id: commit.id.succ, old_path: existing_path, new_path: existing_path) }

      it 'returns a 404' do
        expect(response).to have_http_status(404)
      end
    end
  end
end
