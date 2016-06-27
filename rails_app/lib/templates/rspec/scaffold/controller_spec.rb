require 'rails_helper'

<% module_namespacing do -%>
describe <%= controller_class_name %>Controller do

  # This should return the minimal set of attributes required to create a valid
  # <%= class_name %>. As you add validations to <%= class_name %>, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) {
    attributes_for :<%= file_name %>
  }

  let(:invalid_attributes) {
    skip("Add a hash of attributes invalid for your model")
  }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # <%= controller_class_name %>Controller. Be sure to keep this updated too.
  let(:valid_session) { {} }

<% unless options[:singleton] -%>
  describe "GET #index" do
    it "assigns all <%= table_name.pluralize %> as @<%= table_name.pluralize %>" do
      <%= file_name %> = <%= class_name %>.create! valid_attributes
      get :index, {}, valid_session
      expect(assigns(:<%= table_name %>)).to eq([<%= file_name %>])
    end
  end

<% end -%>
  describe "GET #show" do
    it "assigns the requested <%= ns_file_name %> as @<%= ns_file_name %>" do
      <%= file_name %> = <%= class_name %>.create! valid_attributes
      get :show, { id: <%= file_name %>.to_param }, valid_session
      expect(assigns(:<%= ns_file_name %>)).to eq(<%= file_name %>)
    end
  end

  describe "GET #new" do
    it "assigns a new <%= ns_file_name %> as @<%= ns_file_name %>" do
      get :new, {}, valid_session
      expect(assigns(:<%= ns_file_name %>)).to be_a_new(<%= class_name %>)
    end
  end

  describe "GET #edit" do
    it "assigns the requested <%= ns_file_name %> as @<%= ns_file_name %>" do
      <%= file_name %> = <%= class_name %>.create! valid_attributes
      get :edit, { id: <%= file_name %>.to_param }, valid_session
      expect(assigns(:<%= ns_file_name %>)).to eq(<%= file_name %>)
    end
  end

  describe "POST #create" do
    context "with valid params" do
      it "creates a new <%= class_name %>" do
        expect {
          post :create, {:<%= ns_file_name %> => valid_attributes}, valid_session
        }.to change(<%= class_name %>, :count).by(1)
      end

      it "assigns a newly created <%= ns_file_name %> as @<%= ns_file_name %>" do
        post :create, {:<%= ns_file_name %> => valid_attributes}, valid_session
        expect(assigns(:<%= ns_file_name %>)).to be_a(<%= class_name %>)
        expect(assigns(:<%= ns_file_name %>)).to be_persisted
      end

      it "redirects to the created <%= ns_file_name %>" do
        post :create, {:<%= ns_file_name %> => valid_attributes}, valid_session
        expect(response).to redirect_to(<%= class_name %>.last)
      end
    end

    context "with invalid params" do
      it "assigns a newly created but unsaved <%= ns_file_name %> as @<%= ns_file_name %>" do
        post :create, {:<%= ns_file_name %> => invalid_attributes}, valid_session
        expect(assigns(:<%= ns_file_name %>)).to be_a_new(<%= class_name %>)
      end

      it "re-renders the 'new' template" do
        post :create, {:<%= ns_file_name %> => invalid_attributes}, valid_session
        expect(response).to render_template("new")
      end
    end
  end

  describe "PUT #update" do
    context "with valid params" do
      let(:new_attributes) {
        skip("Add a hash of attributes valid for your model")
      }

      it "updates the requested <%= ns_file_name %>" do
        <%= file_name %> = <%= class_name %>.create! valid_attributes
        put :update, { id: <%= file_name %>.to_param, :<%= ns_file_name %> => new_attributes }, valid_session
        <%= file_name %>.reload
        skip("Add assertions for updated state")
      end

      it "assigns the requested <%= ns_file_name %> as @<%= ns_file_name %>" do
        <%= file_name %> = <%= class_name %>.create! valid_attributes
        put :update, { id: <%= file_name %>.to_param, :<%= ns_file_name %> => valid_attributes }, valid_session
        expect(assigns(:<%= ns_file_name %>)).to eq(<%= file_name %>)
      end

      it "redirects to the <%= ns_file_name %>" do
        <%= file_name %> = <%= class_name %>.create! valid_attributes
        put :update, { id: <%= file_name %>.to_param, :<%= ns_file_name %> => valid_attributes }, valid_session
        expect(response).to redirect_to(<%= file_name %>)
      end
    end

    context "with invalid params" do
      it "assigns the <%= ns_file_name %> as @<%= ns_file_name %>" do
        <%= file_name %> = <%= class_name %>.create! valid_attributes
        put :update, { id: <%= file_name %>.to_param, :<%= ns_file_name %> => invalid_attributes }, valid_session
        expect(assigns(:<%= ns_file_name %>)).to eq(<%= file_name %>)
      end

      it "re-renders the 'edit' template" do
        <%= file_name %> = <%= class_name %>.create! valid_attributes
        put :update, { id: <%= file_name %>.to_param, :<%= ns_file_name %> => invalid_attributes }, valid_session
        expect(response).to render_template("edit")
      end
    end
  end

  describe "DELETE #destroy" do
    it "destroys the requested <%= ns_file_name %>" do
      <%= file_name %> = <%= class_name %>.create! valid_attributes
      expect {
        delete :destroy, { id: <%= file_name %>.to_param }, valid_session
      }.to change(<%= class_name %>, :count).by(-1)
    end

    it "redirects to the <%= table_name %> list" do
      <%= file_name %> = <%= class_name %>.create! valid_attributes
      delete :destroy, { id: <%= file_name %>.to_param }, valid_session
      expect(response).to redirect_to(<%= index_helper %>_url)
    end
  end

end
<% end -%>
