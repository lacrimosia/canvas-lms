#
# Copyright (C) 2011 - 2016 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

# @API Originality Reports
# @internal
#
# API for OriginalityReports
#
# Originality reports may be used by external tools providing plagiarism
# detection services to give an originality score to an assignment
# submission's file. An originality report has an associated
# file ID (the file submitted by the student) and an originality score
# between 0 and 1.
#
# @model OriginalityReport
#     {
#       "id": "OriginalityReport",
#       "description": "",
#       "properties": {
#         "id": {
#           "description": "The id of the OriginalityReport",
#           "example": "4",
#           "type": "integer"
#         },
#         "file_id": {
#           "description": "The id of the file receiving the originality score",
#           "example": "8",
#           "type": "integer"
#         },
#         "originality_score": {
#           "description": "A number between 0 and 1 representing the originality score",
#           "example": "0.16",
#           "type": "number"
#         },
#         "originality_report_file_id": {
#           "description": "The ID of the file within Canvas containing the originality report document (if provided)",
#           "example": "23",
#           "type": "integer"
#         },
#         "originality_report_url": {
#           "description": "A non-LTI launch URL where the originality score of the file may be found.",
#           "example": "http://www.example.com/report",
#           "type": "string"
#         },
#         "originality_report_lti_url" :{
#           "description": "An LTI url where the originality score of the file may be found",
#           "example": "http://www.my-tool.com/report",
#           "type": "string"
#         }
#       }
#     }
class OriginalityReportsApiController < ApplicationController
  before_action :require_user
  before_action :attachment_in_context

  # @API Create an Originality Report
  # Create a new OriginalityReport for the specified file
  #
  # @argument originality_report[file_id] [Required, Integer]
  #   The id of the file being given an originality score.
  #
  # @argument originality_report[originality_score] [Required, Float]
  #   A number between 0 and 1 representing the measure of the
  #   specified file's originality.
  #
  # @argument originality_report[originality_report_url] [String]
  #   The URL where the originality report for the specified
  #   file may be found.
  #
  # @argument originality_report[originality_report_lti_url] [String]
  #   The URL of an LTI tool launch where the originality report of
  #   the specified file may be found. Takes precedence over
  #   originality_report_url in the Canvas UI.
  #
  # @argument originality_report[originality_report_file_id] [Integer]
  #    The ID of the file within Canvas that contains the originality
  #    report for the submitted file provided in the request URL.
  #
  # @returns OriginalityReport
  def create
    if authorized_action(@assignment.context, @current_user, :manage_grades) &&
      @assignment.context.root_account.feature_enabled?(:plagiarism_detection_platform)
      report_attributes = strong_params.require(:originality_report).permit(permitted_attributes).to_hash.merge(
        {submission_id: strong_params.require(:submission_id)})

      @report = OriginalityReport.new(report_attributes)
      begin
        successful_save = @report.save
      rescue ActiveRecord::RecordNotUnique
        @report.errors.add(:base, I18n.t('the specified file with file_id already has an originality report'))
      end

      if successful_save
        render json: api_json(@report, @current_user, session), status: :created
      else
        render json: @report.errors, status: :bad_request
      end
    end
  end

  private

  def permitted_attributes
    [:originality_score,
     :file_id,
     :originality_report_file_id,
     :originality_report_url,
     :originality_report_lti_url].freeze
  end

  def attachment_in_context
    @assignment = Assignment.find(params[:assignment_id])
    attachment = Attachment.find(strong_params.require(:originality_report)[:file_id])
    submission = Submission.find(params[:submission_id])

    unless submission.assignment == @assignment && submission.attachments.include?(attachment)
      head :unauthorized
    end
  end
end