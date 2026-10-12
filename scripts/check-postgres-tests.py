import xml.etree.ElementTree as ET
from pathlib import Path
report=Path('redemption-service/target/surefire-reports/TEST-com.singtel.redemptionservice.PostgresConcurrencyTest.xml')
root=ET.parse(report).getroot()
assert int(root.attrib['tests'])>=4,'PostgreSQL tests did not execute'
assert int(root.attrib.get('skipped',0))==0,'PostgreSQL integration tests skipped: Docker is mandatory in CI'
assert int(root.attrib.get('errors',0))==0 and int(root.attrib.get('failures',0))==0
