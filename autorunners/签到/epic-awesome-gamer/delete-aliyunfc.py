import sys,os
from typing import List

from alibabacloud_tea_openapi.client import Client as OpenApiClient
from alibabacloud_credentials.client import Client as CredentialClient
from alibabacloud_credentials.models import Config as CredentialConfig
from alibabacloud_tea_openapi import models as open_api_models
from alibabacloud_tea_util import models as util_models
from alibabacloud_openapi_util.client import Client as OpenApiUtilClient


class aliyun_eci:
    def __init__(self, region: str = 'ap-northeast-1', endpoint: str = None):
        self.region = region
        self.endpoint = endpoint or f'eci.{region}.aliyuncs.com'

        cred_config = CredentialConfig(
            type='access_key',
            access_key_id='',
            access_key_secret='',
        )
        cred = CredentialClient(cred_config)
        config = open_api_models.Config(credential=cred)
        config.endpoint = self.endpoint
        self.client = OpenApiClient(config)

    def describe_container_groups(self) -> List[dict]:
        params = open_api_models.Params(
            action='DescribeContainerGroups',
            version='2018-08-08',
            protocol='HTTPS',
            method='POST',
            auth_type='AK',
            style='RPC',
            pathname='/',
            req_body_type='json',
            body_type='json'
        )

        queries = {
            'RegionId': self.region,
        }

        request = open_api_models.OpenApiRequest(
            query=OpenApiUtilClient.query(queries)
        )
        runtime = util_models.RuntimeOptions()
        response = self.client.call_api(params, request, runtime)
        return response.get('body', {}).get('ContainerGroups', [])

    def delete_container_group(self, container_group_id: str):
        params = open_api_models.Params(
            action='DeleteContainerGroup',
            version='2018-08-08',
            protocol='HTTPS',
            method='POST',
            auth_type='AK',
            style='RPC',
            pathname='/',
            req_body_type='json',
            body_type='json'
        )

        queries = {
            'RegionId': self.region,
            'ContainerGroupId': container_group_id
        }

        request = open_api_models.OpenApiRequest(
            query=OpenApiUtilClient.query(queries)
        )
        runtime = util_models.RuntimeOptions()
        return self.client.call_api(params, request, runtime)

    def run_cleanup(self, target_name: str):
        print(f"查询容器组：正在查找 ContainerGroupName = '{target_name}' 的项")
        groups = self.describe_container_groups()

        filtered = [
            g for g in groups
            if g.get("ContainerGroupName") == target_name and g.get("ContainerGroupId")
        ]

        if not filtered:
            print("未找到匹配的容器组，或没有合法的 ContainerGroupId。")
            return

        for group in filtered:
            group_id = group['ContainerGroupId']
            group_name = group['ContainerGroupName']
            print(f"正在删除：{group_name} ({group_id})")
            try:
                self.delete_container_group(group_id)
                print(f"✅ 删除成功：{group_name}")
            except Exception as e:
                print(f"❌ 删除失败：{group_name}, 错误：{e}")

def app(event, context):
    aliyun = aliyun_eci()
    return aliyun.run_cleanup("epic-awesome-gamer")