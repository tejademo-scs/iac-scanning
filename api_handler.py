import socket
import time
from abc import ABC, abstractmethod
from typing import Optional
from datetime import datetime, timedelta
from datamesh_common.logging.loggers import transformation_logger as logger
from googleapiclient.errors import HttpError
from googleapiclient.discovery import build, Resource
from oauth2client.service_account import ServiceAccountCredentials
from datamesh_datalake_curated.custom_operations.google.clickstream.settings import TABLE_COLS


class AnalyticsReportingAPIHandler(ABC):
    """Google analytics reporting API handler class that has methods for building a service object and pulling data"""

    @abstractmethod
    def build_service_object(self, credentials) -> Optional[Resource]:
        """
        Authorizes, builds and returns an Analytics Reporting API service object.
        """
        raise NotImplementedError()

    @abstractmethod
    def pull_data(self):
        """
        Method for API request sending, pulling and handling data.
        """
        raise NotImplementedError()


class AnalyticsReportingAPIv4(AnalyticsReportingAPIHandler):
    def __init__(self, credentials: dict, params: dict):
        self.service_object = self.build_service_object(credentials)
        self.params = params

    def build_service_object(self, credentials) -> Optional[Resource]:
        socket.setdefaulttimeout(900)

        service_account_static_fields = {
            "type": "service_account",
            "client_x509_cert_url": f"https://www.googleapis.com/robot/v1/metadata/x509/{credentials['client_email']}",
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        }
        credentials.update(service_account_static_fields)
        credentials = ServiceAccountCredentials.from_json_keyfile_dict(
            credentials, ["https://www.googleapis.com/auth/analytics.readonly"]
        )

        service_object = build("analyticsreporting", "v4", credentials=credentials)
        logger.info("Authorization successful and service object received.")
        return service_object

    def get_batch_data(self, body):
        """
        Each request is attempted a maximum of 5 times, with a timeout starting at 10 seconds and increasing by 10
        seconds with each subsequent attempt. If the service is unavailable after that amount of time has passed, then
        a manual inspection is needed.
        """

        for attempts in range(1, 7):
            try:
                return self.service_object.reports().batchGet(body=body).execute()  # pylint: disable=no-member"
            except HttpError:
                if attempts == 6:
                    logger.info("Attempts exhausted, these errors require manual inspection.")
                    raise
                logger.info(
                    "There was a service unavailable error - either the GA API is down or there have been too many "
                    + "requests. Attempting again after "
                    + str(10 * attempts)
                    + " seconds for date range: ["
                    + str(body["reportRequests"][0]["dateRanges"][0]["startDate"])
                    + " - "
                    + str(body["reportRequests"][0]["dateRanges"][0]["endDate"])
                    + "] and page token: "
                    + str(body["reportRequests"][0]["pageToken"])
                    + "."
                )
                time.sleep(60 * attempts)
        return None

    def pull_data(self):
        """
        Queries the API with the given date range and view, with each request corresponding to a
        week until the full range is completed. Then, it parses each response(dimensions and metrics are flattened),
        and returns them as a list of lists(rows), along with the column names.
        """

        day = timedelta(days=1)
        week = timedelta(days=7)
        date_range_end = datetime.fromisoformat(self.params["date_range_end"]).date()

        data, column_names = [], []
        current_week_start = datetime.fromisoformat(self.params["date_range_start"]).date()
        logger.info("Pulling data week by week started.")
        while current_week_start <= date_range_end:
            request_start_date = current_week_start
            request_end_date = min(current_week_start + week - day, date_range_end)  # inclusive date range
            page_token = "0"
            while page_token:
                body = {
                    "reportRequests": [
                        {
                            "viewId": self.params["view_id"],
                            "dateRanges": [
                                {"startDate": request_start_date.isoformat(), "endDate": request_end_date.isoformat()}
                            ],
                            "metrics": [{"expression": x} for x in TABLE_COLS[self.params["table_name"]]["metrics"]],
                            "dimensions": [{"name": x} for x in TABLE_COLS[self.params["table_name"]]["dimensions"]],
                            "includeEmptyRows": True,
                            "pageToken": page_token,
                            "pageSize": 100000,
                        }
                    ]
                }
                batch_get = self.get_batch_data(body)

                if not column_names:
                    column_header = batch_get["reports"][0]["columnHeader"]
                    table_dimensions = column_header["dimensions"]
                    table_metrics = [metric["name"] for metric in column_header["metricHeader"]["metricHeaderEntries"]]
                    column_names = table_dimensions
                    column_names.extend(table_metrics)

                if "rows" in batch_get["reports"][0]["data"]:
                    flatten = []
                    rows = batch_get["reports"][0]["data"]["rows"]
                    for row in rows:
                        dimension_values = row["dimensions"]
                        metric_values = row["metrics"][0]["values"]
                        dimension_values.extend(metric_values)
                        flatten.append(dimension_values)
                    data.extend(flatten)

                page_token = batch_get["reports"][0].get("nextPageToken")

            current_week_start += week

        if data:
            logger.info(f"Data pulling successfully finished. {len(data)} rows in total were collected.")
        else:
            logger.info("Data pulling successfully finished, but no data was available for the given parameters.")
        return data, column_names
