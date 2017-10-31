# frozen_string_literal: true

require 'spec_helper'
require 'better_html'

describe ERBLint::Linters::ErbSafety do
  let(:linter_config) { {} }
  let(:linter) { described_class.new(linter_config) }
  subject(:linter_errors) { linter.lint_file(file) }

  before do
    allow(BetterHtml::Config).to receive(:javascript_safe_methods).and_return(['to_json'])
  end

  context 'interpolate a variable in js attribute' do
    let(:file) { <<~FILE }
      <a onclick="alert('<%= foo %>')">
    FILE

    it { expect(linter_errors).to eq [unsafe_interpolate_error] }
  end

  context 'interpolate a variable in js attribute calling safe method' do
    let(:file) { <<~FILE }
      <a onclick="alert(<%= foo.to_json %>)">
    FILE

    it { expect(linter_errors).to eq [] }
  end

  context 'interpolate a variable in js attribute calling safe method inside string interpolation' do
    let(:file) { <<~FILE }
      <a onclick="alert(<%= "hello \#{foo.to_json}" %>)">
    FILE

    it { expect(linter_errors).to eq [] }
  end

  context 'html_safe in any attribute is unsafe' do
    let(:file) { <<~FILE }
      <div title="<%= foo.html_safe %>">
    FILE

    it { expect(linter_errors).to eq [unsafe_html_safe] }
  end

  context 'html_safe in any attribute is unsafe despite having to_json' do
    let(:file) { <<~FILE }
      <a onclick="<%= foo.to_json.html_safe %>">
    FILE

    it { expect(linter_errors).to eq [unsafe_html_safe] }
  end

  context '<== in any attribute is unsafe' do
    let(:file) { <<~FILE }
      <div title="<%== foo %>">
    FILE

    it { expect(linter_errors).to eq [unsafe_erb_interpolate] }
  end

  context '<== in any attribute is unsafe despite having to_json' do
    let(:file) { <<~FILE }
      <div title="<%== foo.to_json %>">
    FILE

    it { expect(linter_errors).to eq [unsafe_erb_interpolate] }
  end

  context 'raw in any attribute is unsafe' do
    let(:file) { <<~FILE }
      <div title="<%= raw foo %>">
    FILE

    it { expect(linter_errors).to eq [unsafe_raw] }
  end

  context 'raw in any attribute is unsafe despite having to_json' do
    let(:file) { <<~FILE }
      <div title="<%= raw foo.to_json %>">
    FILE

    it { expect(linter_errors).to eq [unsafe_raw] }
  end

  context 'unsafe erb in <script>' do
    let(:file) { <<~FILE }
      <script>var foo = <%= unsafe %>;</script>
    FILE

    it { expect(linter_errors).to eq [unsafe_javascript_tag_interpolate] }
  end

  context 'safe erb in <script>' do
    let(:file) { <<~FILE }
      <script>var foo = <%= unsafe.to_json %>;</script>
    FILE

    it { expect(linter_errors).to eq [] }
  end

  context 'safe erb in <script> when raw is present' do
    let(:file) { <<~FILE }
      <script>var foo = <%= raw unsafe.to_json %>;</script>
    FILE

    it { expect(linter_errors).to eq [] }
  end

  context 'statements not allowed in <script> tags' do
    let(:file) { <<~FILE }
      <script><% if foo? %>var foo = 1;<% end %></script>
    FILE

    it { expect(linter_errors).to eq [erb_statements_not_allowed] }
  end

  private

  def unsafe_interpolate_error(line: 1)
    {
      message: "erb interpolation in javascript attribute must call '(...).to_json'",
      line: line
    }
  end

  def unsafe_html_safe(line: 1)
    {
      message: "erb interpolation with '<%= (...).html_safe %>' inside html attribute is never safe",
      line: line
    }
  end

  def unsafe_erb_interpolate(line: 1)
    {
      message: "erb interpolation with '<%==' inside html attribute is never safe",
      line: line
    }
  end

  def unsafe_raw(line: 1)
    {
      message: "erb interpolation with '<%= raw(...) %>' inside html attribute is never safe",
      line: line
    }
  end

  def unsafe_javascript_tag_interpolate(line: 1)
    {
      message: "erb interpolation in javascript tag must call '(...).to_json'",
      line: line
    }
  end

  def erb_statements_not_allowed(line: 1)
    {
      message: "erb statement not allowed here; did you mean '<%=' ?",
      line: line
    }
  end
end
